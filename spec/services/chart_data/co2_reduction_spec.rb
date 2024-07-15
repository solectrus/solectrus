describe ChartData::Co2Reduction do
  subject(:to_h) { described_class.new(timeframe:).to_h }

  let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

  around { |example| travel_to(now, &example) }

  before do
    influx_batch do
      # Fill last hour with data
      12.times do |i|
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => 28_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)
      end
    end
  end

  context 'when timeframe is current MONTH' do
    let(:timeframe) { Timeframe.month }

    it 'returns value' do
      expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(11)
    end
  end

  context 'when timeframe is NOW' do
    let(:timeframe) { Timeframe.now }

    it 'returns value' do
      expect(to_h.dig(:datasets, 0, :data).last).to eq(
        468, # 28 kW * 401 g/kWh / 24
      )
    end
  end
end
