describe Sensor::Query::ChangedSince do
  subject(:changed_since) { described_class.new(:wallbox_car_connected, since: 2.hours.ago).call }

  def add_reading(value, time)
    add_influx_point(
      name: Sensor::Config.measurement(:wallbox_car_connected),
      fields: { Sensor::Config.field(:wallbox_car_connected) => value },
      time:,
    )
  end

  context 'without any data' do
    it { is_expected.to be(false) }
  end

  context 'with a change since the time' do
    before do
      influx_batch do
        add_reading(1, 90.minutes.ago)
        add_reading(0, 1.hour.ago)
      end
    end

    it { is_expected.to be(true) }
  end

  context 'with a change before the time only' do
    before do
      influx_batch do
        add_reading(0, 3.hours.ago)
        add_reading(1, 150.minutes.ago)
        add_reading(1, 1.hour.ago)
      end
    end

    it { is_expected.to be(false) }
  end

  # A boolean is true for each positive number
  context 'with two positive numbers' do
    before do
      influx_batch do
        add_reading(1, 90.minutes.ago)
        add_reading(2, 1.hour.ago)
      end
    end

    it { is_expected.to be(false) }
  end
end
