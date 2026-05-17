class Sensor::Chart::CustomPower < Sensor::Chart::PowerSplitterBase
  def initialize(timeframe:, sensor_name:, variant: nil)
    super(timeframe:, variant:)
    @sensor_name = sensor_name
  end

  def color_class(_sensor)
    'bg-sensor-house'
  end

  private

  def base_sensor_name
    @sensor_name
  end

  def grid_sensor_name
    :"#{@sensor_name}_grid"
  end

  def pv_sensor_name
    :"#{@sensor_name}_pv"
  end

  # Bridge only cadence jitter, never genuine idle phases. In the live "now"
  # view a sensor polled every ~28s occasionally misses a single 30s bucket
  # (issue #5567); 2 minutes covers that jitter while staying far below a
  # real consumer idle phase. The day/hours views use 5-min buckets, coarse
  # enough that any real cadence fills every bucket, so bridging is disabled
  # there (0): an empty bucket is a genuine idle phase that must stay 0, and
  # bridging would merge separate on/off cycles into one block.
  def gap_bridge_limit
    timeframe.now? ? 2.minutes.in_milliseconds : 0
  end

  # A consumer reads 0 W while idle, but the collector stops writing (Shelly)
  # instead of streaming zeros. Every gap left after bridge_short_gaps --
  # every empty bucket in day/hours, every non-jitter gap in the now view --
  # is flattened to 0 W. See Sensor::Chart::Base#fill_gaps_with_zero.
  def fill_gaps_with_zero?
    true
  end
end
