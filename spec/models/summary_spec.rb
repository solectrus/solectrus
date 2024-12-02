# == Schema Information
#
# Table name: summaries
#
#  avg_battery_soc               :float
#  avg_car_battery_soc           :float
#  avg_case_temp                 :float
#  avg_heatpump_score            :float
#  avg_outdoor_temp              :float
#  car_driving_distance          :float
#  date                          :date             not null, primary key
#  max_battery_charging_power    :float
#  max_battery_discharging_power :float
#  max_battery_soc               :float
#  max_car_battery_soc           :float
#  max_case_temp                 :float
#  max_grid_export_power         :float
#  max_grid_import_power         :float
#  max_heatpump_heating_power    :float
#  max_heatpump_power            :float
#  max_house_power               :float
#  max_inverter_power            :float
#  max_outdoor_temp              :float
#  max_wallbox_power             :float
#  min_battery_soc               :float
#  min_car_battery_soc           :float
#  min_case_temp                 :float
#  min_outdoor_temp              :float
#  sum_battery_charging_power    :float
#  sum_battery_discharging_power :float
#  sum_custom_01_power           :float
#  sum_custom_02_power           :float
#  sum_custom_03_power           :float
#  sum_custom_04_power           :float
#  sum_custom_05_power           :float
#  sum_custom_06_power           :float
#  sum_custom_07_power           :float
#  sum_custom_08_power           :float
#  sum_custom_09_power           :float
#  sum_custom_10_power           :float
#  sum_grid_export_power         :float
#  sum_grid_import_power         :float
#  sum_heatpump_heating_power    :float
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
  end

  describe 'single summary' do
    let(:summary) { described_class.create!(date:, updated_at:) }

    before { travel_to Time.new(2024, 7, 1, 12, 0, 0, '+02:00') }

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

    context 'when date is long ago, updated some days later' do
      let(:date) { 1.year.ago.to_date }
      let(:updated_at) { (date + 5.days).middle_of_day }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is yesterday, updated today shortly after midnight' do
      let(:date) { Date.yesterday }
      let(:updated_at) { date.beginning_of_day + 1.day + 5.minutes }

      include_examples 'tests for fresh and stale', false
    end

    context 'when date is yesterday, updated after required distance' do
      let(:date) { Date.yesterday }
      let(:updated_at) { date.beginning_of_day + 1.day + 10.hours }

      include_examples 'tests for fresh and stale', true
    end

    context 'when date is today, updated shortly after midnight' do
      let(:date) { Date.current }
      let(:updated_at) { date.beginning_of_day + 5.minutes }

      include_examples 'tests for fresh and stale', false
    end

    context 'when date is in the future, updated out of tolerance' do
      let(:date) { Date.tomorrow }
      let(:updated_at) { 10.minutes.ago }

      include_examples 'tests for fresh and stale', false
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

      include_examples 'Freshness tests', true, 100, []
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

      include_examples 'Freshness tests',
                       false,
                       75,
                       (Date.new(2023, 2, 1)..Date.new(2023, 2, 7)).to_a
    end

    context 'when no summaries are present' do
      it { is_expected.to eq(0) }

      include_examples 'Freshness tests',
                       false,
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
            custom_01_power
            custom_02_power
            custom_03_power
            custom_04_power
            custom_05_power
            custom_06_power
            custom_07_power
            custom_08_power
            custom_09_power
            custom_10_power
            grid_export_power
            grid_import_power
            heatpump_heating_power
            heatpump_power
            heatpump_power_grid
            heatpump_score
            house_power
            house_power_grid
            inverter_power
            inverter_power_forecast
            outdoor_temp
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
