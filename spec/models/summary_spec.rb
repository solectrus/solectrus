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

  shared_examples 'result' do |expected_completion_rate, expected_completed_status|
    it 'returns the correct completion rate' do
      expect(described_class.completion_rate(timeframe)).to be_within(0.05).of(
        expected_completion_rate,
      )
    end

    it 'returns the correct completed status' do
      expect(described_class.completed?(timeframe)).to eq(
        expected_completed_status,
      )
    end
  end

  describe 'completion_rate and completed?' do
    context 'when day in the past, updated on next day' do
      let(:timeframe) { Timeframe.new(5.days.ago.to_date.iso8601) }
      let(:updated_at) { timeframe.date + 1.day + 10.hours }

      before do
        described_class.create!(
          date: timeframe.date,
          sum_inverter_power: 42,
          updated_at:,
        )
      end

      include_examples 'result', 100, true
    end

    context 'when day in the past, updated on same day' do
      let(:timeframe) { Timeframe.new(5.days.ago.to_date.iso8601) }
      let(:updated_at) { timeframe.date + 10.hours }

      before do
        described_class.create!(
          date: timeframe.date,
          sum_inverter_power: 42,
          updated_at:,
        )
      end

      include_examples 'result', 0, false
    end

    context 'when today, updated a few minutes ago' do
      let(:timeframe) { Timeframe.day }
      let(:updated_at) { 3.minutes.ago }

      before do
        described_class.create!(
          date: timeframe.date,
          sum_inverter_power: 42,
          updated_at:,
        )
      end

      include_examples 'result', 100, true
    end

    context 'when day in the past, record missing' do
      let(:timeframe) { Timeframe.new(5.days.ago.to_date.iso8601) }
      let(:updated_at) { nil }

      include_examples 'result', 0, false
    end

    context 'when timeframe is a month in the past, all summaries updated on the next day' do
      let(:timeframe) { Timeframe.new('2024-02') }

      before do
        timeframe
          .effective_beginning_date
          .upto(timeframe.effective_ending_date) do |date|
            described_class.create!(
              date:,
              sum_inverter_power: 42,
              updated_at: date + 1.day + 10.hours,
            )
          end
      end

      include_examples 'result', 100, true
    end

    context 'when timeframe is a month in the past, all summaries updated on the next day - except one' do
      let(:timeframe) { Timeframe.new('2024-02') }

      before do
        timeframe
          .effective_beginning_date
          .upto(timeframe.effective_ending_date) do |date|
            described_class.create!(
              date:,
              sum_inverter_power: 42,
              updated_at:
                date.day == 1 ? date + 10.hours : date + 1.day + 10.hours,
            )
          end
      end

      include_examples 'result', 96.6, false
    end

    context 'when timeframe is current month, all summaries up to date' do
      let(:timeframe) { Timeframe.month }

      before do
        timeframe
          .effective_beginning_date
          .upto(timeframe.effective_ending_date) do |date|
            described_class.create!(
              date:,
              sum_inverter_power: 42,
              updated_at: date.today? ? 3.minutes.ago : date + 1.day + 10.hours,
            )
          end
      end

      include_examples 'result', 100, true
    end
  end
end
