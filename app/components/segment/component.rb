class Segment::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor, **options, &block)
    super()
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
  def hidden = options[:hidden]
  def tooltip = options[:tooltip].nil? || options[:tooltip]

  def title
    options.key?(:title) ? options[:title] : sensor.display_name
  end

  delegate :data, :timeframe, to: :parent

  def link_to_or_div(url, **, &)
    url ? link_to(url, **, &) : tag.div(**, &)
  end

  def url
    case helpers.controller_namespace
    when 'inverter'
      unless sensor.name == :inverter_power_difference
        inverter_home_path(
          sensor_name: sensor.name,
          timeframe: parent.timeframe,
        )
      end
    when 'house'
      house_home_path(sensor_name: sensor.name, timeframe: parent.timeframe)
    when 'heatpump'
      heatpump_home_path(
        sensor_name: 'heatpump_heating_power',
        timeframe: parent.timeframe,
      )
    else
      balance_home_path(sensor_name: sensor.name, timeframe: parent.timeframe)
    end
  end

  def default_value
    @default_value ||= data.public_send(sensor.name).to_f
  end

  def default_percent
    @default_percent ||= data.public_send(:"#{sensor.name}_percent").to_f
  end

  def costs
    if %i[
         wallbox_power
         heatpump_power
         house_power
         house_power_without_custom
         battery_charging_power
       ].exclude?(sensor.name) && !sensor.name.to_s.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field = "#{sensor.name}_costs".sub('_power', '')
    # Example: custom_01_costs,  house_without_custom_costs, wallbox_costs, ...

    data.public_send(costs_field)
  end

  def sensors_with_grid_ratio
    %i[
      wallbox_power
      heatpump_power
      house_power
      battery_charging_power
      house_power_without_custom
    ] + Sensor::Config.custom_power_sensors.map(&:name)
  end

  def power_grid_ratio
    return unless sensor.name.in?(sensors_with_grid_ratio)

    data.public_send(:"#{sensor.name}_grid_ratio")
  end

  def costs_grid
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor.name)

    costs_field = "#{sensor.name}_costs_grid".sub('_power', '')
    data.public_send(costs_field)
  end

  def costs_pv
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor.name)

    costs_field = "#{sensor.name}_costs_pv".sub('_power', '')
    data.public_send(costs_field)
  end

  def now?
    parent.timeframe.now?
  end

  def masked_value
    unsigned_value = value

    case sensor.name
    when :grid_import_power, :battery_discharging_power
      -unsigned_value
    else
      unsigned_value
    end
  end

  def icon_scale
    return 100 if peak.nil?

    Scale.new(target: 90..150, max: peak).result(value)
  end

  def balance?
    return @balance if defined?(@balance)

    @balance =
      sensor.name.in?(
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
      ) ||
        sensor.name.in?(
          Sensor::Config.house_power_excluded_custom_sensors.map(&:name),
        )
  end

  def inverter?
    return @inverter if defined?(@inverter)

    @inverter = sensor.category == :inverter
  end

  def house?
    return @house if defined?(@house)

    @house =
      sensor.name == :house_power_without_custom ||
        (
          sensor.name.to_s.match?(/^custom_power_(\d{2})$/) &&
            !sensor.name.in?(
              Sensor::Config.house_power_excluded_custom_sensors.map(&:name),
            )
        )
  end

  def heatpump?
    return @heatpump if defined?(@heatpump)

    @heatpump =
      sensor.name.in? %i[
                        heatpump_power_pv
                        heatpump_power_grid
                        heatpump_power_env
                        heatpump_heating_power
                        heatpump_tank_temp
                      ]
  end

  def default_color_class
    # Special case: house_power_without_custom has hardcoded semi-transparent color
    if sensor.name == :house_power_without_custom
      return 'bg-white/20 dark:bg-black/20 text-slate-700 dark:text-slate-400'
    end

    # House sensors (custom_power_*) use dynamic index for color intensity
    if house? && color_index
      "#{sensor.color_bg(index: color_index)} #{sensor.color_text(index: color_index)}"
    else
      # All other sensors use static colors
      "#{sensor.color_bg} #{sensor.color_text}"
    end
  end

  private

  def tiny?
    percent < 0.3
  end

  def number_method
    now? ? :to_watt : :to_watt_hour
  end
end
