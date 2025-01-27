describe ChartData::Co2Reduction do
  let(:co2_reduction_data) { described_class.new(timeframe:) }

  context 'when data for month is present' do
    before do
      influx_batch do
        # Fill one hour (12:00 - 13:00) with 28 kW power
        13.times do |i|
          time = date.beginning_of_day + (5.minutes * i)

          add_influx_point name: measurement_inverter_power,
                           fields: {
                             field_inverter_power => 28_000,
                           },
                           time:
        end
      end

      create_summary(date:, values: [[:inverter_power, :sum, 28_000]])
    end

    let(:date) { Date.new(2024, 9, 1) }
    let(:timeframe) { Timeframe.new('2024-09') }

    it 'calculates CO2 reduction' do
      hash = co2_reduction_data.to_h
      expect(hash.dig(:datasets, 0, :data, 0)).to eq(11_228) # 28 kW * 0,401 kg/kWh
    end
  end

  context 'when current data is present' do
    before do
      add_influx_point name: measurement_inverter_power,
                       fields: {
                         field_inverter_power => 28_000,
                       },
                       time: 1.minute.ago
    end

    let(:timeframe) { Timeframe.now }

    it 'returns value' do
      hash = co2_reduction_data.to_h
      expect(hash.dig(:datasets, 0, :data).last).to eq(
        467_833, # 28 kW * 0,401 kg/kWh / 24 * 1000
      )
    end
  end
end
