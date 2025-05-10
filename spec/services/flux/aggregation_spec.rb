describe Flux::Aggregation do
  subject(:aggregation) { described_class.new(sensors:) }

  let(:sensors) { [:inverter_power_1] }
  let(:date) { Date.new(2024, 10, 1) }

  before do
    influx_batch do
      # Fill one hour (12:00 - 13:00) with 10 kW power
      13.times do |i|
        time = date.middle_of_day + (5.minutes * i)

        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => 10_000,
                         },
                         time:
      end

      # Fill one hour (14:00 - 15:00) with 5 kW power
      13.times do |i|
        time = date.middle_of_day + 2.hours + (5.minutes * i)

        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => 5_000,
                         },
                         time:
      end
    end
  end

  describe '#call' do
    subject(:call) { aggregation.call(timeframe:) }

    let(:timeframe) { Timeframe.new(date.iso8601) }

    it do
      is_expected.to eq(
        {
          max_inverter_power_1: 10_000,
          min_inverter_power_1: 5_000,
          mean_inverter_power_1: 7_500,
        },
      )
    end
  end
end
