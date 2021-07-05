describe PowerChart do
  let(:measurement) { "Test#{described_class}" }

  let(:chart) do
    described_class.new(fields: ['inverter_power'], measurements: [measurement])
  end

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    (0..11).each do |index|
      add_influx_point name: measurement,
                       fields: {
                         inverter_power: (index + 1) * 1000,
                       },
                       time: (beginning + index.month).end_of_month
      add_influx_point name: measurement,
                       fields: {
                         inverter_power: (index + 1) * 1000,
                       },
                       time: (beginning + index.month).beginning_of_month
    end

    add_influx_point name: measurement, fields: { inverter_power: 14_000 }
  end

  around { |example| freeze_time(&example) }

  describe '#now' do
    subject(:result) { chart.now }

    it { is_expected.to have(1.hour / 5.seconds).items }

    it 'contains last data point' do
      last = result.last

      expect(last[1]).to eq(14.0)
      expect(last[0]).to be_within(5.seconds).of(Time.current)
    end
  end

  describe '#year' do
    subject(:result) { chart.year(beginning) }

    it { is_expected.to have(12).items }

    it 'contains last and first data point' do
      expect(result.first).to eq([beginning + 1.hour, 2.0])
      expect(result.last).to eq(
        [beginning.end_of_year.beginning_of_month + 1.hour, 12.0],
      )
    end
  end
end
