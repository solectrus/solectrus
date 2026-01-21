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

  COLOR_TEXT_LIGHT_BG = 'text-slate-700 dark:text-slate-400'.freeze
  private_constant :COLOR_TEXT_LIGHT_BG

  COLOR_TEXT_DARK_BG = 'text-slate-100 dark:text-slate-300'.freeze
  private_constant :COLOR_TEXT_DARK_BG

  COLOR_BACKGROUNDS_10 = %w[
    bg-slate-500/10
    bg-slate-500/20
    bg-slate-500/30
    bg-slate-500/40
    bg-slate-500/50
    bg-slate-500/60
    bg-slate-500/70
    bg-slate-500/80
    bg-slate-500/90
    bg-slate-500
  ].freeze
  private_constant :COLOR_BACKGROUNDS_10

  COLOR_BACKGROUNDS_20 = %w[
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
    bg-slate-500/55
    bg-slate-500/60
    bg-slate-500/65
    bg-slate-500/70
    bg-slate-500/75
    bg-slate-500/80
    bg-slate-500/85
    bg-slate-500/90
    bg-slate-500/95
    bg-slate-500
  ].freeze
  private_constant :COLOR_BACKGROUNDS_20

  color do |index|
    # Choose color set based on total number of custom sensors
    total_sensors = Sensor::Config.house_power_included_custom_sensors.length
    backgrounds =
      total_sensors <= 10 ? COLOR_BACKGROUNDS_10 : COLOR_BACKGROUNDS_20

    # Use provided index (for dynamic sorting by consumption) or @number (static)
    effective_index = index || @number
    text_threshold = (backgrounds.length / 2.0).ceil
    text =
      effective_index >= text_threshold ? COLOR_TEXT_DARK_BG : COLOR_TEXT_LIGHT_BG

    { background: backgrounds[effective_index - 1], text: }
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
