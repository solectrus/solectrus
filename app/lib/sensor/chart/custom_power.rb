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

  # Bridge cadence gaps only in the live "now" view. Its 30s buckets are
  # finer than the write cadence of slowly-polled sensors (e.g. cameras every
  # ~28s), so empty buckets there are mostly a cadence artefact and must be
  # smoothed (issue #5552). The day/hours views use 5-min buckets, coarse
  # enough that a real consumer cadence fills every bucket -- so an empty
  # bucket is a genuine idle phase and must stay 0, not be bridged across
  # (which would merge separate on/off cycles into one block).
  def bridge_gaps?
    timeframe.now?
  end

  # A consumer reads 0 W while idle, but the collector stops writing (Shelly)
  # instead of streaming zeros. Every gap left after bridge_gaps? -- every
  # empty bucket in day/hours, the long idle phases in the now view -- is
  # flattened to 0 W. See Sensor::Chart::Base#fill_gaps_with_zero.
  def fill_gaps_with_zero?
    true
  end
end
