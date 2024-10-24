# == Schema Information
#
# Table name: summaries
#
#  avg_battery_soc               :float
#  avg_car_battery_soc           :float
#  avg_case_temp                 :float
#  date                          :date             not null, primary key
#  max_battery_charging_power    :float
#  max_battery_discharging_power :float
#  max_battery_soc               :float
#  max_car_battery_soc           :float
#  max_case_temp                 :float
#  max_grid_export_power         :float
#  max_grid_import_power         :float
#  max_heatpump_power            :float
#  max_house_power               :float
#  max_inverter_power            :float
#  max_wallbox_power             :float
#  min_battery_soc               :float
#  min_car_battery_soc           :float
#  min_case_temp                 :float
#  sum_battery_charging_power    :float
#  sum_battery_discharging_power :float
#  sum_grid_export_power         :float
#  sum_grid_import_power         :float
#  sum_heatpump_power            :float
#  sum_heatpump_power_grid       :float
#  sum_house_power               :float
#  sum_house_power_grid          :float
#  sum_inverter_power            :float
#  sum_inverter_power_forecast   :float
#  sum_wallbox_power             :float
#  sum_wallbox_power_grid        :float
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_summaries_on_updated_at  (updated_at)
#
describe Summary do
  it 'can be created' do
    summary =
      described_class.create!(date: Date.current, sum_inverter_power: 42)

    expect(summary.date).to eq(Date.current)
    expect(summary.sum_inverter_power).to eq(42)
  end

  shared_examples 'tests for fresh and stale' do |is_fresh|
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

    it 'returns correct .fresh scope' do
      if is_fresh
        expect(described_class.fresh).to include(summary)
      else
        expect(described_class.fresh).not_to include(summary)
      end
    end
  end

  describe 'single summary' do
    let(:summary) { described_class.create!(date:, updated_at:) }

    context 'when date is in the past, updated on next day' do
      let(:date) { 5.days.ago.to_date }
      let(:updated_at) { (date + 1.day).middle_of_day }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is in the past, updated on the same day' do
      let(:date) { 5.days.ago.to_date }
      let(:updated_at) { date.middle_of_day }

      include_examples 'tests for fresh and stale', false
    end

    context 'when date is today, updated a few minutes ago' do
      let(:date) { Date.current }
      let(:updated_at) { 3.minutes.ago }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is today, updated out of tolerance' do
      let(:date) { Date.current }
      let(:updated_at) { 10.minutes.ago }

      include_examples 'tests for fresh and stale', false
    end

    context 'when date is in the future, updated within tolerance' do
      let(:date) { Date.tomorrow }
      let(:updated_at) { 3.minutes.ago }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is yesterday, updated today shortly after midnight (testing timezone)' do
      let(:date) { Date.yesterday }
      let(:updated_at) { Date.current + 3.minutes }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is in the future, updated out of tolerance' do
      let(:date) { Date.tomorrow }
      let(:updated_at) { 10.minutes.ago }

      include_examples 'tests for fresh and stale', false
    end
  end

  shared_examples 'tests for fresh_percentage and missing_or_stale_days' do |fresh_percentage, missing_or_stale_days|
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

      include_examples 'tests for fresh_percentage and missing_or_stale_days',
                       100,
                       []
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

      include_examples 'tests for fresh_percentage and missing_or_stale_days',
                       75,
                       (Date.new(2023, 2, 1)..Date.new(2023, 2, 7)).to_a
    end

    context 'when no summaries are present' do
      it { is_expected.to eq(0) }

      include_examples 'tests for fresh_percentage and missing_or_stale_days',
                       0,
                       (Date.new(2023, 2, 1)..Date.new(2023, 2, 28)).to_a
    end
  end

  describe 'Monitoring' do
    let(:current_config) { described_class.config }

    describe '.sensors' do
      subject { described_class.sensors }

      it 'returns a sorted list of sensors' do
        is_expected.to eq(
          %i[
            battery_charging_power
            battery_discharging_power
            battery_soc
            car_battery_soc
            case_temp
            grid_export_power
            grid_import_power
            heatpump_power
            heatpump_power_grid
            house_power
            house_power_grid
            inverter_power
            inverter_power_forecast
            wallbox_power
            wallbox_power_grid
          ],
        )
      end
    end

    describe '.validate!' do
      subject(:validation) { described_class.validate! }

      before { described_class.create!(date: Date.current) }

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
          expect { validation }.to change(described_class, :count).from(1).to(0)
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
          expect { validation }.to change(described_class, :count).from(1).to(0)
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
