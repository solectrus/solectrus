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

  # Background colors with max 50% opacity for readable text contrast
  # Scales from 5% to 50% in steps matching the number of sensors
  COLOR_BACKGROUNDS_10 = %w[
    bg-slate-500/5
    bg-slate-500/10
    bg-slate-500/15
    bg-slate-500/20
    bg-slate-500/25
    bg-slate-500/30
    bg-slate-500/35
    bg-slate-500/40
    bg-slate-500/45
    bg-slate-500/50
  ].freeze
  private_constant :COLOR_BACKGROUNDS_10

  # Finer gradation for up to 20 sensors (2.5% steps from 5% to 55%)
  # Static list required for Tailwind to recognize classes at build time
  COLOR_BACKGROUNDS_20 = %w[
    bg-slate-500/5
    bg-slate-500/[7.5%]
    bg-slate-500/10
    bg-slate-500/[12.5%]
    bg-slate-500/15
    bg-slate-500/[17.5%]
    bg-slate-500/20
    bg-slate-500/[22.5%]
    bg-slate-500/25
    bg-slate-500/[27.5%]
    bg-slate-500/30
    bg-slate-500/[32.5%]
    bg-slate-500/35
    bg-slate-500/[37.5%]
    bg-slate-500/40
    bg-slate-500/[42.5%]
    bg-slate-500/45
    bg-slate-500/[47.5%]
    bg-slate-500/50
    bg-slate-500/[52.5%]
  ].freeze
  private_constant :COLOR_BACKGROUNDS_20

  color do |index|
    # Choose color set based on total number of custom sensors
    total_sensors = Sensor::Config.house_power_included_custom_sensors.length
    backgrounds =
      total_sensors <= 10 ? COLOR_BACKGROUNDS_10 : COLOR_BACKGROUNDS_20

    # Use provided index (for dynamic sorting by consumption) or @number (static)
    effective_index = index || @number

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
