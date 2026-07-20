class Sensor::Chart::TotalConsumption < Sensor::Chart::Base
  # Show the total consumption broken down into its parts. Order is the stacking
  # order (bottom to top): house, then any custom consumers excluded from
  # house_power, then heat pump, then wallbox. house_power is already net of all
  # of these (they are subtracted from it), so the stacked segments add up to the
  # total without double counting -- mirroring the total_consumption calculation.
  COMPONENT_SENSOR_NAMES = %i[house_power heatpump_power wallbox_power].freeze
  public_constant :COMPONENT_SENSOR_NAMES

  def label
    Sensor::Registry[:total_consumption].display_name
  end

  def options
    super.deep_merge(
      plugins: {
        legend: legend_options,
      },
      scales: {
        x: {
          stacked: true,
        },
        y: {
          stacked: true,
        },
      },
    )
  end

  private

  def chart_sensor_names
    @chart_sensor_names ||= begin
      names = COMPONENT_SENSOR_NAMES.select { |name| Sensor::Config.exists?(name) }
      insert_excluded_custom_sensors(names)
      names
    end
  end

  # Insert excluded custom consumers right after house_power (they were
  # subtracted from it), so the stack mirrors the total_consumption calculation.
  def insert_excluded_custom_sensors(names)
    return if excluded_custom_sensor_names.empty?

    insert_pos = (names.index(:house_power) || -1) + 1
    names.insert(insert_pos, *excluded_custom_sensor_names)
  end

  def excluded_custom_sensor_names
    @excluded_custom_sensor_names ||=
      Sensor::Config.house_power_excluded_custom_sensors.map(&:name)
  end

  # Chart.js stacked line fill (fill: '-1') needs a numeric value at every
  # index, so every nil left after Base#bridge_short_gaps collapses to 0.
  def fill_gaps_with_zero?
    true
  end

  # Heat pump, wallbox and excluded custom consumers are subtracted from
  # house_power, so their nil buckets mean "no power" (0) and must stay 0 --
  # bridging them would carry a value that house_power has not been reduced by,
  # showing the same wattage twice (issue #5517). Only house_power is bridged.
  #
  # Mirrors TotalConsumption#calculate, which sums house_power with
  # heatpump_power and wallbox_power whenever they are *configured* - not only
  # when they appear in INFLUX_EXCLUDE_FROM_HOUSE_POWER. So from this chart's
  # perspective they are always "already inside house_power", hence a fixed
  # sensor check rather than the Sensor::Config lookup PowerBalance needs.
  def bridge_gaps?(sensor_name)
    sensor_name == :house_power
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor = Sensor::Registry[chart_data[:sensor_name]]
      {
        id: sensor.name.to_s,
        label: sensor.display_name,
        data: chart_data[:data],
      }.merge(style_for_dataset(sensor))
    end
  end

  def style_for_dataset(sensor)
    position = chart_sensor_names.index(sensor.name) || 0
    fill =
      if type == 'line'
        position.zero? ? 'origin' : '-1'
      else
        true
      end

    style_for_sensor(sensor).merge(
      fill:,
      stack: 'TotalConsumption',
      noGradient: true,
    )
  end

  # Excluded custom consumers were subtracted from house_power, so they render in
  # the house color here -- matching their segments in the balance sheet, which
  # also use the house color (see balance/component).
  def color_class(sensor)
    if excluded_custom_sensor_names.include?(sensor.name)
      Sensor::Registry[:house_power].color_background
    else
      super
    end
  end
end
