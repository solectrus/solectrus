describe Sensor::SummaryBuilder do
  subject(:builder) { described_class.new(timeframe) }

  let(:timeframe) { Timeframe.day }

  before { stub_feature(:heatpump) }

  describe '#initialize' do
    context 'with Timeframe for a day' do
      it 'accepts' do
        expect(builder.timeframe).to eq(timeframe)
      end
    end

    context 'with other Timeframe' do
      let(:timeframe) { Timeframe.week }

      it 'raises an error' do
        expect { builder }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#call' do
    subject(:call) { builder.call }

    before do
      freeze_time

      # Setup test data with power values over the current day for integral and aggregation calculation
      influx_batch do
        # Create power data throughout the day (every 4 hours)
        (0..5).each do |time_offset|
          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_1), # "my-pv"
            fields: {
              Sensor::Config.field(:inverter_power_1) =>
                (time_offset * 100) + 2000, # 2000, 2100, 2200, 2300, 2400, 2500
            },
            time: Time.current.beginning_of_day + (time_offset * 4).hours,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_2), # "balcony"
            fields: {
              Sensor::Config.field(:inverter_power_2) =>
                (time_offset * 25) + 300.0, # 300, 325, 350, 375, 400, 425
            },
            time: Time.current.beginning_of_day + (time_offset * 4).hours,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) => (time_offset * 50) + 2500, # 2500, 2550, 2600, 2650, 2700, 2750
            },
            time: Time.current.beginning_of_day + (time_offset * 4).hours,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:heatpump_power),
            fields: {
              Sensor::Config.field(:heatpump_power) =>
                (time_offset * 50) + 1500, # 1500, 1550, 1600, 1650, 1700, 1750
            },
            time: Time.current.beginning_of_day + (time_offset * 4).hours,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:case_temp),
            fields: {
              Sensor::Config.field(:case_temp) => 30,
            },
            time: Time.current.beginning_of_day + (time_offset * 4).hours,
          )
        end
      end
    end

    it 'returns a Sensor::Data::Single object' do
      expect(call).to be_a(Sensor::Data::Single)
    end

    it 'collects data from real InfluxDB integral calculations' do
      expect(call.inverter_power_1(:sum)).to eq(45_000)
      expect(call.inverter_power_1(:max)).to eq(2500)

      expect(call.inverter_power_2(:sum)).to eq(7_250)
      expect(call.inverter_power_2(:max)).to eq(425)

      expect(call.heatpump_power(:sum)).to eq(32_500)
      expect(call.house_power(:sum)).to eq(20_000)

      expect(call.case_temp(:max)).to eq(30)
      expect(call.case_temp(:min)).to eq(30)
      expect(call.case_temp(:avg)).to eq(30)
    end

    context 'when no data exists in timeframe' do
      let(:timeframe) { Timeframe.new(6.days.ago.to_date.iso8601) } # 6 days ago - no data

      it 'returns data object with nil values' do
        # When no data exists, integral returns 0 but gets converted to nil
        # Aggregations return nil when no data
        expect(call.inverter_power_1(:sum)).to be_nil
        expect(call.inverter_power_1(:max)).to be_nil
        expect(call.house_power(:sum)).to be_nil
        expect(call.house_power(:max)).to be_nil
      end
    end
  end
end
