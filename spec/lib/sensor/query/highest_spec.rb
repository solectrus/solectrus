describe Sensor::Query::Highest do
  subject(:highest) { described_class.new(:car_battery_soc_1, from: 2.hours.ago, to: 30.minutes.ago).call }

  def add_reading(value, time)
    add_influx_point(
      name: Sensor::Config.measurement(:car_battery_soc_1),
      fields: { Sensor::Config.field(:car_battery_soc_1) => value },
      time:,
    )
  end

  context 'without any data' do
    it { is_expected.to be_nil }
  end

  context 'with readings in and around the period' do
    before do
      influx_batch do
        add_reading(100.0, 3.hours.ago)
        add_reading(99.0, 90.minutes.ago)
        add_reading(90.0, 1.hour.ago)
        add_reading(95.0, 10.minutes.ago)
      end
    end

    it { is_expected.to eq(99.0) }
  end
end
