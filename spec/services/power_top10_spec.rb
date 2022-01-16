describe PowerTop10 do
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
                       time: (beginning + index.month).end_of_month.end_of_day
      add_influx_point name: measurement,
                       fields: {
                         inverter_power: (index + 1) * 1000,
                       },
                       time:
                         (beginning + index.month).beginning_of_month
                           .beginning_of_day
    end

    add_influx_point name: measurement, fields: { inverter_power: 14_000 }
  end

  around do |example|
    travel_to Time.zone.local(2021, 12, 31, 12, 0, 0), &example
  end

  describe '#years' do
    subject { chart.years }

    it { is_expected.to have(1).items }
    it { is_expected.to all(be_a(Hash)) }
  end

  describe '#months' do
    subject { chart.months }

    it { is_expected.to have(2).items }
    it { is_expected.to all(be_a(Hash)) }
  end

  describe '#days' do
    subject { chart.days }

    it { is_expected.to have(3).items }
    it { is_expected.to all(be_a(Hash)) }
  end
end
