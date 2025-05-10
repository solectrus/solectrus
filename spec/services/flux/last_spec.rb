describe Flux::Last do
  subject(:last) { described_class.new(sensors:) }

  let(:sensors) { [:inverter_power_1] }
  let(:time) { 1.minute.ago.beginning_of_minute }

  before do
    add_influx_point name: measurement_inverter_power_1,
                     fields: {
                       field_inverter_power_1 => 10_000,
                     },
                     time:
  end

  describe '#call' do
    subject(:call) { last.call }

    it { is_expected.to eq({ inverter_power_1: 10_000, time: }) }
  end
end
