class Segment::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor, **options, &block)
    super
    @sensor = sensor
    @options = options
    @block = block
  end

  attr_reader :sensor, :options, :block

  def parent = options[:parent]
  def peak = options[:peak]
  def inline = options[:inline]
  def color_index = options[:color_index]
  def color_class = options[:color_class] || default_color_class
  def value = options[:value] || default_value
  def percent = options[:percent] || default_percent

  def title
    options.key?(:title) ? options[:title] : SensorConfig.x.name(sensor)
  end

  def icon_class
    options.key?(:icon_class) ? options[:icon_class] : default_icon_class
  end

  delegate :calculator, :timeframe, to: :parent

  def link_to_or_div(url, **, &)
    url ? link_to(url, **, &) : tag.div(**, &)
  end

  def url
    case helpers.controller_namespace
    when 'house'
      house_home_path(sensor:, timeframe: parent.timeframe)
    else
      root_path(
        sensor: sensor.to_s.sub(/_import|_export|_charging|_discharging/, ''),
        timeframe: parent.timeframe,
      )
    end
  end

  def default_value
    @default_value ||= calculator.public_send(sensor).to_f
  end

  def default_percent
    @default_percent ||= calculator.public_send(:"#{sensor}_percent").to_f
  end

  def costs
    if %i[
         wallbox_power
         heatpump_power
         house_power
         house_power_without_custom
         battery_charging_power
       ].exclude?(sensor) && !sensor.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field = "#{sensor}_costs".sub('_power', '')
    # Example: custom_01_costs,  house_without_custom_costs, wallbox_costs, ...

    calculator.public_send(costs_field)
  end

  def sensors_with_grid_ratio
    %i[
      wallbox_power
      heatpump_power
      house_power
      battery_charging_power
      house_power_without_custom
    ] + SensorConfig.x.existing_custom_sensor_names
  end

  def power_grid_ratio
    return unless sensor.in?(sensors_with_grid_ratio)

    calculator.public_send(:"#{sensor}_grid_ratio")
  end

  def costs_grid
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor)

    costs_field = "#{sensor}_costs_grid".sub('_power', '')
    calculator.public_send(costs_field)
  end

  def costs_pv
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor)

    costs_field = "#{sensor}_costs_pv".sub('_power', '')
    calculator.public_send(costs_field)
  end

  def now?
    parent.timeframe.now?
  end

  def masked_value
    unsigned_value = value

    case sensor
    when :grid_import_power, :battery_discharging_power
      -unsigned_value
    else
      unsigned_value
    end
  end

  def icon_size
    return 100 if peak.nil?

    Scale.new(target: 80..300, max: peak).result(value)
  end

  def default_icon_class
    case sensor
    when :grid_export_power, :grid_import_power
      'fa-bolt'
    when :inverter_power
      'fa-sun'
    when :battery_discharging_power, :battery_charging_power
      battery_class
    when :house_power
      'fa-home'
    when :heatpump_power
      'fa-fan'
    when :wallbox_power
      'fa-car'
    end
  end

  def battery_class
    unless calculator.respond_to?(:battery_soc) && calculator.battery_soc
      return 'fa-battery-half'
    end

    if calculator.battery_soc < 15
      'fa-battery-empty'
    elsif calculator.battery_soc < 30
      'fa-battery-quarter'
    elsif calculator.battery_soc < 60
      'fa-battery-half'
    elsif calculator.battery_soc < 85
      'fa-battery-three-quarters'
    else
      'fa-battery-full'
    end
  end

  def balance?
    return @balance if defined?(@balance)

    @balance =
      sensor.in?(
        %i[
          grid_export_power
          inverter_power
          battery_discharging_power
          battery_charging_power
          house_power
          heatpump_power
          wallbox_power
          grid_import_power
          heatpump_power_grid
        ],
      ) || sensor.in?(SensorConfig.x.excluded_custom_sensor_names)
  end

  def house?
    return @house if defined?(@house)

    @house =
      sensor == :house_power_without_custom ||
        (
          sensor.to_s.match?(/^custom_power_(\d{2})$/) &&
            !sensor.in?(SensorConfig.x.excluded_custom_sensor_names)
        )
  end

  def default_color_class
    if balance?
      default_color_class_for_balance
    elsif house?
      default_color_class_for_house
    end
  end

  private

  def default_color_class_for_balance
    case sensor
    when :grid_export_power, :inverter_power
      'bg-green-600 dark:bg-green-800/80'
    when :battery_discharging_power, :battery_charging_power
      'bg-green-700 dark:bg-green-900/70'
    when :house_power, /^custom_power_(\d{2})$/
      'bg-slate-500 dark:bg-slate-600/90'
    when :heatpump_power
      'bg-slate-600 dark:bg-slate-600/70'
    when :wallbox_power
      'bg-slate-700 dark:bg-slate-600/50'
    when :grid_import_power, :heatpump_power_grid
      'bg-red-600 dark:bg-red-800/80'
    end
  end

  COLOR_SET_10 = %i[
    bg-slate-500/10
    bg-slate-500/20
    bg-slate-500/30
    bg-slate-500/40
    bg-slate-500/50
    bg-slate-500/60
    bg-slate-500/70
    bg-slate-500/80
    bg-slate-500/90
    bg-slate-500/100
  ].freeze
  private_constant :COLOR_SET_10

  COLOR_SET_20 = %i[
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
    bg-slate-500/100
  ].freeze
  private_constant :COLOR_SET_20

  def default_color_class_for_house
    if sensor == :house_power_without_custom
      return 'bg-white/20 dark:bg-black/20 text-slate-700 dark:text-slate-400'
    end

    match = sensor.to_s.match(/^custom_power_(\d{2})$/)
    index = color_index || match[1].to_i
    color =
      if SensorConfig.x.existing_custom_sensor_count <= 10
        COLOR_SET_10[index - 1]
      else
        COLOR_SET_20[index - 1]
      end

    "#{color} text-slate-700 dark:text-slate-400"
  end

  def font_size(max:)
    return 0 if percent.nil? || percent < 6

    [percent + 90, max].min
  end

  def large?
    percent > 33
  end

  def tiny?
    percent < 0.3
  end
end
