# == Schema Information
#
# Table name: summaries
#
#  date       :date             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_summaries_on_updated_at  (updated_at)
#
describe Summary do
  it 'can be created' do
    summary =
      described_class
        .create!(date: Date.current)
        .tap do |s|
          s.values.create! field: 'inverter_power',
                           aggregation: 'sum',
                           value: 42
        end

    expect(summary.date).to eq(Date.current)
    expect(summary.values.count).to eq(1)
    expect(summary.values.first.value).to eq(42)
    expect(summary.values.first.summary).to eq(summary)
  end

  describe '#threshold_date' do
    subject { described_class.threshold_date }

    let(:date) { Date.current }

    context 'when before required distance' do
      before { travel_to date.beginning_of_day + 5.minutes }

      it { is_expected.to eq(Date.yesterday) }
    end

    context 'when after required distance' do
      before { travel_to date.beginning_of_day + 10.hours }

      it { is_expected.to eq(Date.current) }
    end
  end

  shared_examples 'fresh and stale' do |is_fresh|
    it 'returns correct fresh?' do
      if is_fresh
        expect(summary).to be_fresh
      else
        expect(summary).not_to be_fresh
      end
    end

    it 'returns correct stale?' do
      if is_fresh
        expect(summary).not_to be_stale
      else
        expect(summary).to be_stale
      end
    end
  end

  describe 'single summary' do
    let(:summary) { described_class.create!(date:, updated_at:) }

    before { travel_to Time.new(2024, 7, 1, 12, 0, 0, '+02:00') }

    context 'when date is in the past, updated on next day' do
      let(:date) { 5.days.ago.to_date }
      let(:updated_at) { (date + 1.day).middle_of_day }

      it_behaves_like 'fresh and stale', true
    end

    context 'when date is in the past, updated on the same day' do
      let(:date) { 5.days.ago.to_date }
      let(:updated_at) { date.middle_of_day }

      it_behaves_like 'fresh and stale', false
    end

    context 'when date is today, updated a few minutes ago' do
      let(:date) { Date.current }
      let(:updated_at) { 3.minutes.ago }

      it_behaves_like 'fresh and stale', true
    end

    context 'when date is today, updated out of tolerance' do
      let(:date) { Date.current }
      let(:updated_at) { 10.minutes.ago }

      it_behaves_like 'fresh and stale', false
    end

    context 'when date is in the future, updated within tolerance' do
      let(:date) { Date.tomorrow }
      let(:updated_at) { 3.minutes.ago }

      it_behaves_like 'fresh and stale', true
    end

    context 'when date is long ago, updated some days later' do
      let(:date) { 1.year.ago.to_date }
      let(:updated_at) { (date + 5.days).middle_of_day }

      it_behaves_like 'fresh and stale', true
    end

    context 'when date is yesterday, updated today shortly after midnight' do
      let(:date) { Date.yesterday }
      let(:updated_at) { date.beginning_of_day + 1.day + 5.minutes }

      it_behaves_like 'fresh and stale', false
    end

    context 'when date is yesterday, updated after required distance' do
      let(:date) { Date.yesterday }
      let(:updated_at) { date.beginning_of_day + 1.day + 10.hours }

      it_behaves_like 'fresh and stale', true
    end

    context 'when date is today, updated shortly after midnight' do
      let(:date) { Date.current }
      let(:updated_at) { date.beginning_of_day + 5.minutes }

      it_behaves_like 'fresh and stale', false
    end

    context 'when date is in the future, updated out of tolerance' do
      let(:date) { Date.tomorrow }
      let(:updated_at) { 10.minutes.ago }

      it_behaves_like 'fresh and stale', false
    end
  end

  shared_examples 'Freshness tests' do |fresh, fresh_percentage, missing_or_stale_days|
    it 'returns correct fresh?' do
      expect(described_class.fresh?(timeframe)).to eq(fresh)
    end

    it 'returns correct fresh_percentage' do
      expect(described_class.fresh_percentage(timeframe)).to eq(
        fresh_percentage,
      )
    end

    it 'returns correct missing_or_stale_days' do
      expect(
        described_class.missing_or_stale_days(
          from: timeframe.effective_beginning_date,
          to: timeframe.effective_ending_date,
        ),
      ).to eq(missing_or_stale_days)
    end
  end

  describe 'multiple summaries' do
    subject { described_class.fresh_percentage(timeframe) }

    let(:timeframe) { Timeframe.new('2023-02') }

    context 'when all summaries are present and fresh' do
      before do
        (timeframe.beginning.to_date..timeframe.ending.to_date).each do |date|
          described_class.create!(date:, updated_at: date + 2.days)
        end
      end

      it_behaves_like 'Freshness tests', true, 100, []
    end

    context 'when all summaries are present, but some are stale and some are fresh' do
      before do
        (timeframe.beginning.to_date..timeframe.ending.to_date).each do |date|
          described_class.create!(
            date:,
            updated_at: date.day <= 7 ? date.middle_of_day : date + 2.days,
          )
        end
      end

      it_behaves_like 'Freshness tests',
                      false,
                      75,
                      (Date.new(2023, 2, 1)..Date.new(2023, 2, 7)).to_a
    end

    context 'when no summaries are present' do
      it { is_expected.to eq(0) }

      it_behaves_like 'Freshness tests',
                      false,
                      0,
                      (Date.new(2023, 2, 1)..Date.new(2023, 2, 28)).to_a
    end
  end

  describe 'Monitoring' do
    let(:current_config) { described_class.config }

    before do
      create_summary(
        date: Date.current,
        values: [['inverter_power', 'sum', 42]],
      )
    end

    describe '.reset!' do
      it 'deletes all summaries with values' do
        expect { described_class.reset! }.to change(
          described_class,
          :count,
        ).from(1).to(0).and change(SummaryValue, :count).from(1).to(0)
      end
    end

    describe '.validate!' do
      subject(:validation) { described_class.validate! }

      context 'when stored config matches the current config' do
        before { Setting.summary_config = current_config }

        it 'does not delete summaries' do
          expect { validation }.not_to change(described_class, :count)
        end

        it 'does not update the stored config' do
          expect { validation }.not_to change(Setting, :summary_config)
        end
      end

      context 'when stored config differs from the current config' do
        before { Setting.summary_config = { time_zone: 'Australia/Sydney' } }

        it 'deletes all summaries' do
          expect { validation }.to change(described_class, :count).from(1).to(
            0,
          ).and change(SummaryValue, :count).from(1).to(0)
        end

        it 'updates the stored config' do
          expect { validation }.to change(Setting, :summary_config).to(
            current_config,
          )
        end
      end

      context 'when no stored config exists' do
        before { Setting.summary_config = nil }

        it 'deletes all summaries' do
          expect { validation }.to change(described_class, :count).from(1).to(
            0,
          ).and change(SummaryValue, :count).from(1).to(0)
        end

        it 'updates the stored config' do
          expect { validation }.to change(Setting, :summary_config).to(
            current_config,
          )
        end
      end
    end
  end
end
