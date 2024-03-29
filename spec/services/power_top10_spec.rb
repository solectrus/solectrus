describe PowerTop10 do
  let(:chart) { described_class.new(sensor: :inverter_power, calc:, desc:) }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    influx_batch do
      12.times do |index|
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => (index + 1) * 1000,
                         },
                         time:
                           (beginning + index.months).end_of_month.end_of_day -
                             12.hours
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => (index + 1) * 1000,
                         },
                         time:
                           (
                             beginning + index.months
                           ).beginning_of_month.beginning_of_day
      end

      add_influx_point name: measurement_inverter_power,
                       fields: {
                         field_inverter_power => 14_000,
                       }
    end
  end

  around do |example|
    travel_to Time.zone.local(2021, 12, 1, 12, 0, 0), &example
  end

  context 'when descending' do
    let(:desc) { true }
    let(:calc) { 'sum' }

    describe '#years' do
      subject { chart.years }

      it { is_expected.to have(2).items }
      it { is_expected.to all(be_a(Hash)) }
    end

    describe '#months' do
      subject { chart.months }

      it { is_expected.to have(3).items }
      it { is_expected.to all(be_a(Hash)) }
    end

    describe '#weeks' do
      subject { chart.weeks }

      it { is_expected.to have(3).items }
      it { is_expected.to all(be_a(Hash)) }
    end

    describe '#days' do
      subject { chart.days }

      it { is_expected.to have(4).items }
      it { is_expected.to all(be_a(Hash)) }
    end
  end

  context 'when ascending' do
    let(:desc) { false }
    let(:calc) { 'max' }

    describe '#years' do
      subject { chart.years }

      it { is_expected.to have(0).items }
    end

    describe '#months' do
      subject { chart.months }

      it { is_expected.to have(1).items }
      it { is_expected.to all(be_a(Hash)) }
    end

    describe '#weeks' do
      subject { chart.weeks }

      it { is_expected.to have(2).items }
      it { is_expected.to all(be_a(Hash)) }
    end

    describe '#days' do
      subject { chart.days }

      it { is_expected.to have(3).items }
      it { is_expected.to all(be_a(Hash)) }
    end
  end
end
