# The charging power of now and a day on the car page: the power curve of the
# wallbox, without the split into PV and grid. A charging session belongs to a
# full day, so a shorter timeframe has no columns of sessions (see
# Sensor::Chart::CarSessions).
class Sensor::Chart::CarChargingPower < Sensor::Chart::Base
  # Without a wallbox there is no curve. The offsite sessions need a day at
  # least (see Sensor::Chart::CarSessions).
  def supported?
    super && Sensor::Config.exists?(:wallbox_power)
  end

  def chart_sensor_names
    %i[wallbox_power]
  end

  private

  # Same rationale as Sensor::Chart::CustomPower: a wallbox reads 0 W while
  # idle but the collector typically stops writing instead of streaming
  # zeros. Bridge only cadence jitter in the now view (2 min, well below a
  # genuine idle phase); for the day view bridging is disabled so each
  # empty bucket stays a real idle phase.
  def gap_bridge_limit
    timeframe.now? ? 2.minutes.in_milliseconds : 0
  end

  # Flatten every remaining null to 0 W so the leading/trailing edges of
  # the now window -- and any genuine idle phase -- render as a baseline
  # instead of an empty area.
  def fill_gaps_with_zero?
    true
  end

  def build_dataset(sensor_name, chart_data)
    super.merge(stack: Sensor::Chart::CarSessions::STACKS[:energy], summed: true, noGradient: true)
  end
end
