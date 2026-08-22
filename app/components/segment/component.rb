class Segment::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  COSTS_SENSOR_NAMES = %i[
    wallbox_power
    heatpump_power
    house_power
    house_power_without_custom
  ].freeze
  private_constant :COSTS_SENSOR_NAMES

  # What the battery takes in from the grid has no costs of its own -- it is
  # billed to the consumers taking it back out -- so this shows the ratio plus a
  # note instead of an amount (see #costs_note).
  #
  # The discharge is deliberately absent, for the reason the charging chart
  # leaves it whole: its grid share is an attribution from the Power Splitter's
  # ledger and depends on what was stored days earlier. Sitting next to the grid
  # import on the source side, a red bar would read as a grid draw that is not
  # happening. The share stays where it buys something -- in the ratio of the
  # charging, and in the costs of the consumers that took the energy.
  NOTED_SENSOR_NAMES = %i[battery_charging_power].freeze
  private_constant :NOTED_SENSOR_NAMES

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

  def chart_url
    case helpers.controller_namespace
    when 'inverter'
      helpers.inverter_charts_path(
        sensor_name: sensor.name,
        timeframe: parent.timeframe,
      )
    when 'house'
      helpers.house_charts_path(sensor_name: sensor.name, timeframe: parent.timeframe)
    when 'heatpump'
      helpers.heatpump_charts_path(
        sensor_name: 'heatpump_heating_power',
        timeframe: parent.timeframe,
      )
    else
      helpers.balance_charts_path(sensor_name: sensor.name, timeframe: parent.timeframe)
    end
  end

  def default_value
    @default_value ||= data.public_send(sensor.name).to_f
  end

  def default_percent
    @default_percent ||= data.public_send(:"#{sensor.name}_percent").to_f
  end

  # Rendered twice by the template (as condition and as argument), so both this
  # and #power_grid_ratio memoize -- their lookups walk the whole summary.
  def costs
    return @costs if defined?(@costs)

    @costs = fetch_costs
  end

  def sensors_with_grid_ratio
    @sensors_with_grid_ratio ||=
      [
        *COSTS_SENSOR_NAMES,
        *NOTED_SENSOR_NAMES,
        *Sensor::Config.custom_power_sensors.map(&:name),
      ]
  end

  def power_grid_ratio
    return @power_grid_ratio if defined?(@power_grid_ratio)

    @power_grid_ratio =
      if sensor.name.in?(sensors_with_grid_ratio)
        data.public_send(:"#{sensor.name}_grid_ratio")
      end
  end

  # The battery segments show a grid share but no amount of their own. Say
  # where that money went instead, so the gap does not read as "free". Only
  # worth saying while there is a grid share to talk about -- the same
  # condition the red part of the bar is drawn under.
  def costs_note
    return unless sensor.name.in?(NOTED_SENSOR_NAMES)
    return unless power_grid_ratio&.positive?

    t("splitter.costs_note.#{sensor.name}")
  end

  def costs_grid
    sensor_costs(sensor.costs_grid_sensor_name)
  end

  def costs_pv
    sensor_costs(sensor.costs_pv_sensor_name)
  end

  def now?
    parent.timeframe.now?
  end

  def masked_value
    unsigned_value = raw_value
    return if unsigned_value.nil?

    case sensor.name
    when :grid_import_power, :battery_discharging_power
      -unsigned_value
    else
      unsigned_value
    end
  end

  # Current reading without the `.to_f` fallback that #default_value applies,
  # so an absent value stays nil instead of becoming 0.0. "Absent" covers an
  # inactive sensor (e.g. grid_import_power while exporting) and a stale/down
  # source alike. The live chart uses this as its data-value: nil renders a gap
  # and skips the flash, rather than a misleading flat-0 line that can't be
  # told apart from a real 0. The displayed tile keeps its own 0 fallback via
  # SensorValue::Component.
  def raw_value
    options[:value] || data.public_send(sensor.name)
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
    # House sensors (custom_power_*) use dynamic index for color intensity
    if house? && color_index
      [
        sensor.color_background(index: color_index),
        sensor.color_text(index: color_index),
      ].join(' ')
    else
      # All other sensors use static colors
      [
        sensor.color_background,
        sensor.color_text,
      ].join(' ')
    end
  end

  private

  def fetch_costs
    if COSTS_SENSOR_NAMES.exclude?(sensor.name) &&
         !sensor.name.to_s.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field = "#{sensor.name}_costs".sub('_power', '')
    # Example: custom_01_costs, house_without_custom_costs, wallbox_costs, ...
    data.public_send(costs_field)
  end

  # Checked before the policy, because resolving the feature flag is the
  # expensive part and most sensors have no split costs field at all.
  def sensor_costs(costs_field)
    return unless costs_field && data.respond_to?(costs_field)
    return unless ApplicationPolicy.power_splitter?

    data.public_send(costs_field)
  end

  def tiny?
    percent < 0.3
  end
end
