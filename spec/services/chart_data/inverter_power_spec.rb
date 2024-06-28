describe ChartData::InverterPower do
  subject(:chart_data_hash) { described_class.new(timeframe:).call }

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

    it 'returns Hash' do
      expect(chart_data_hash).to be_a(Hash)
      expect(chart_data_hash).to include(:datasets, :labels)

      expect(chart_data_hash.dig(:datasets, 0, :data, now.day - 1)).to eq(28)
    end
  end

  context 'when timeframe is NOW' do
    let(:timeframe) { Timeframe.now }

    it 'returns Hash' do
      expect(chart_data_hash).to be_a(Hash)
      expect(chart_data_hash).to include(:datasets, :labels)

      expect(chart_data_hash.dig(:datasets, 0, :data).last).to eq(28)
    end
  end
end
