describe ChartData do
  subject(:chart_data_hash) do
    call = described_class.new(sensor:, timeframe:).call
    JSON.parse(call)
  end

  let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

  around { |example| travel_to(now, &example) }

  before do
    influx_batch do
      # Fill last hour with data
      12.times do |i|
        add_influx_point name: measurement_grid_import_power,
                         fields: {
                           field_inverter_power => 10_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => 28_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_battery_discharging_power,
                         fields: {
                           field_battery_charging_power => 11_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        # Total origin = 10_000 + 28_000 + 11_000 = 49_000

        ###

        add_influx_point name: measurement_wallbox_power,
                         fields: {
                           field_wallbox_power => 27_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_heatpump_power,
                         fields: {
                           field_heatpump_power => 10_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_house_power,
                         fields: {
                           field_house_power => 15_000, # Includes heatpump of 10_000
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_grid_export_power,
                         fields: {
                           field_grid_export_power => 7000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        # Total usage: 27_000 + 10_000 + 5_000 + 7000 = 49_000
      end
    end
  end

  context 'when timeframe is current MONTH' do
    let(:timeframe) { Timeframe.month }

    context 'when sensor is inverter_power' do
      let(:sensor) { :inverter_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')

        expect(
          chart_data_hash.dig('datasets', 0, 'data', now.day - 1),
        ).to be_within(0.001).of(28)
      end
    end

    context 'when sensor is co2_reduction' do
      let(:sensor) { :co2_reduction }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')

        expect(chart_data_hash.dig('datasets', 0, 'data', now.day - 1)).to eq(
          11, # 28 kW * 401 g/kWh / 1000
        )
      end
    end

    context 'when sensor is wallbox_power' do
      let(:sensor) { :wallbox_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)

        expect(chart_data_hash).to include('datasets', 'labels')
        expect(
          chart_data_hash.dig('datasets', 0, 'data', now.day - 1),
        ).to be_within(0.001).of(27)
      end
    end

    context 'when sensor is heatpump_power' do
      let(:sensor) { :heatpump_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')
        expect(
          chart_data_hash.dig('datasets', 0, 'data', now.day - 1),
        ).to be_within(0.001).of(10)
      end
    end

    context 'when sensor is house_power' do
      let(:sensor) { :house_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')
        expect(
          chart_data_hash.dig('datasets', 0, 'data', now.day - 1),
        ).to be_within(0.001).of(5)
      end
    end
  end

  context 'when timeframe is NOW' do
    let(:timeframe) { Timeframe.now }

    context 'when sensor is inverter_power' do
      let(:sensor) { :inverter_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')

        expect(chart_data_hash.dig('datasets', 0, 'data').last).to be_within(
          0.001,
        ).of(28)
      end
    end

    context 'when sensor is co2_reduction' do
      let(:sensor) { :co2_reduction }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')

        expect(chart_data_hash.dig('datasets', 0, 'data').last).to eq(
          468, # 28 kW * 401 g/kWh / 24
        )
      end
    end

    context 'when sensor is heatpump_power' do
      let(:sensor) { :heatpump_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')
        expect(chart_data_hash.dig('datasets', 0, 'data').last).to be_within(
          0.001,
        ).of(10)
      end
    end

    context 'when sensor is house_power' do
      let(:sensor) { :house_power }

      it 'returns JSON' do
        expect(chart_data_hash).to be_a(Hash)
        expect(chart_data_hash).to include('datasets', 'labels')
        expect(chart_data_hash.dig('datasets', 0, 'data').last).to be_within(
          0.001,
        ).of(5)
      end
    end
  end
end
