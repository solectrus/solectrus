class Sensor::Definitions::CustomPower < Sensor::Definitions::Base
  MAX = 20 # Maximum number of custom sensors
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  def name
    :"custom_power_#{format('%02d', @number)}"
  end

  value unit: :watt, category: :consumer, nameable: true

  aggregations stored: [:sum], top10: true
  trend

  # Consistent text color for all segments (works with light backgrounds)
  COLOR_TEXT = 'text-slate-700 dark:text-slate-400'.freeze
  private_constant :COLOR_TEXT

  # 10 consumer shades (every 2nd entry from the 20-shade scale)
  COLOR_BACKGROUNDS_10 = %w[
    bg-sensor-consumer-01
    bg-sensor-consumer-03
    bg-sensor-consumer-05
    bg-sensor-consumer-07
    bg-sensor-consumer-09
    bg-sensor-consumer-11
    bg-sensor-consumer-13
    bg-sensor-consumer-15
    bg-sensor-consumer-17
    bg-sensor-consumer-19
  ].freeze
  private_constant :COLOR_BACKGROUNDS_10

  # 20 consumer shades (full scale)
  COLOR_BACKGROUNDS_20 = %w[
    bg-sensor-consumer-01
    bg-sensor-consumer-02
    bg-sensor-consumer-03
    bg-sensor-consumer-04
    bg-sensor-consumer-05
    bg-sensor-consumer-06
    bg-sensor-consumer-07
    bg-sensor-consumer-08
    bg-sensor-consumer-09
    bg-sensor-consumer-10
    bg-sensor-consumer-11
    bg-sensor-consumer-12
    bg-sensor-consumer-13
    bg-sensor-consumer-14
    bg-sensor-consumer-15
    bg-sensor-consumer-16
    bg-sensor-consumer-17
    bg-sensor-consumer-18
    bg-sensor-consumer-19
    bg-sensor-consumer-20
  ].freeze
  private_constant :COLOR_BACKGROUNDS_20

  color do |index|
    # Choose color set based on total number of custom sensors
    sensors = Sensor::Config.house_power_included_custom_sensors
    backgrounds =
      sensors.length <= 10 ? COLOR_BACKGROUNDS_10 : COLOR_BACKGROUNDS_20

    # Use provided index (for dynamic sorting by consumption),
    # or position among configured sensors (1-based).
    # @number can't be used directly because sensor numbers may be non-contiguous
    # (e.g. consumer 11 with only 5 configured consumers would cause out-of-bounds).
    position = sensors.index { |s| s.name == name }
    effective_index = index || (position ? position + 1 : 1)

    { background: backgrounds[effective_index - 1], text: COLOR_TEXT }
  end

  chart do |timeframe, variant: nil|
    Sensor::Chart::CustomPower.new(timeframe:, sensor_name: name, variant:)
  end

  def costs_grid_sensor_name
    :"custom_costs_#{format('%02d', @number)}_grid"
  end

  def costs_pv_sensor_name
    :"custom_costs_#{format('%02d', @number)}_pv"
  end
end
