describe ChartData::InverterPower do
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
                         time: 1.hour.ago + (5.minutes * (i + 1))
      end
    end

    create_summary(date: now.to_date, values: [[:inverter_power, :sum, 28_000]])
  end

  context 'when timeframe is current MONTH' do
    let(:timeframe) { Timeframe.month }

    it 'contains value' do
      expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(28_000)
    end
  end

  context 'when timeframe is NOW' do
    let(:timeframe) { Timeframe.now }

    it 'contains value' do
      expect(to_h.dig(:datasets, 0, :data).last).to eq(28_000)
    end
  end
end
