class Insights # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe

  def value(sensor_name = sensor.name)
    return unless data.respond_to?(sensor_name)

    @value ||= {}
    @value[sensor_name] ||= data.public_send(sensor_name).to_f
  end

  def costs
    if %i[
         wallbox_power
         heatpump_power
         house_power
         house_power_without_custom
         battery_power
       ].exclude?(sensor.name) && !sensor.name.to_s.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field =
      if sensor.name == :battery_power
        'battery_charging_costs'
        # NOTE: battery_charging_costs already only includes grid costs (no opportunity costs)
      else
        "#{sensor.name}_costs".sub('_power', '')
        # Example: custom_01_costs, house_without_custom_costs, wallbox_costs, ...
      end

    data.public_send(costs_field)
  end

  def costs_grid
    costs_by_source(:grid)
  end

  def costs_pv
    costs_by_source(:pv)
  end

  def sensors_with_grid_ratio
    %i[
      wallbox_power
      heatpump_power
      house_power
      battery_power
      house_power_without_custom
    ] + Sensor::Config.custom_power_sensors.map(&:name)
  end

  def power_grid_ratio
    return unless sensor.name.in?(sensors_with_grid_ratio)

    if sensor.name == :battery_power
      data.battery_charging_power_grid_ratio
    else
      data.public_send(:"#{sensor.name}_grid_ratio")
    end
  end

  def multi_inverter?
    Sensor::Config.multi_inverter? && ApplicationPolicy.multi_inverter?
  end

  def inverter_sensor_values
    return unless multi_inverter?

    @inverter_sensor_values ||= build_inverter_sensor_data
  end

  def per_day_value
    return unless value
    return if timeframe.days_passed <= 1

    (value / timeframe.days_passed(include_today: true)).round(2)
  end

  def feed_in_revenue
    data.grid_revenue
  end

  delegate :grid_costs,
           :solar_price,
           :battery_charging_power,
           :battery_discharging_power,
           :specific_yield,
           to: :data

  def monthly_trend
    @monthly_trend ||=
      if timeframe.month_like? && Trend.available_for?(sensor:, timeframe:)
        Trend.new(
          sensor:,
          timeframe:,
          current_value: value,
          base: :previous_period,
        )
      end
  end

  def yearly_trend
    @yearly_trend ||=
      if Trend.available_for?(sensor:, timeframe:)
        Trend.new(
          sensor:,
          timeframe:,
          current_value: value,
          base: :previous_year,
        )
      end
  end

  def maximum(key = :value)
    extremum(:max)&.dig(key)
  end

  def minimum(key = :value)
    extremum(:min)&.dig(key)
  end

  def battery_empty_days
    Insights::BatteryEmptyDays.new(timeframe:).call
  end

  def battery_full_days
    Insights::BatteryFullDays.new(timeframe:).call
  end

  def battery_soc_longest_streak
    Insights::BatterySocLongestStreak.new(timeframe:).call
  end

  def heatmap_data
    @heatmap_data ||=
      if timeframe.year?
        Insights::HeatmapYearly.new(sensor:, timeframe:).call
      elsif timeframe.all?
        Insights::HeatmapAllTime.new(sensor:, timeframe:).call
      end
  end

  def data
    @data ||=
      PowerBalance.new(
        Sensor::Query::Total
          .new(timeframe) do |q|
            required_sensors.each do |sensor_name|
              aggregation =
                Sensor::Registry[sensor_name].allowed_aggregations.first || :sum

              q.public_send(aggregation, sensor_name)
            end
          end
          .call,
      )
  end

  private

  def costs_by_source(source)
    return unless ApplicationPolicy.power_splitter?

    # Battery is a special case: it has no opportunity costs (pv_costs) because
    # battery charging is almost exclusively from PV. Only grid costs exist
    # for rare emergency charging from the grid.
    if sensor.name == :battery_power
      return source == :grid ? data.battery_charging_costs : nil
    end

    # Use sensor definition for other power sensors
    costs_field =
      source == :grid ? sensor.costs_grid_sensor_name : sensor.costs_pv_sensor_name
    return unless costs_field

    data.public_send(costs_field)
  end

  def extremum(aggregation)
    # Does not make sense for single-day range
    return if timeframe.days_passed <= 1

    @extremum ||= {}
    @extremum[aggregation] ||= Insights::Extremum.new(
      sensor:,
      timeframe:,
      aggregation:,
    ).call
    @extremum[aggregation]
  end

  def required_sensors
    sensors = [
      main_sensor,
      *inverter_sensors,
      *specific_yield_sensor,
      *house_power_excluded_sensors,
      *grid_sensor,
      *battery_sensors,
      *grid_power_sensors,
      *grid_power_cost_sensors,
      *cost_sensors,
    ]
    sensors.compact!
    sensors.uniq!
    sensors
  end

  def main_sensor
    sensor.name if Sensor::Config.exists?(sensor.name, check_policy: false)
  end

  def inverter_sensors
    return [] unless inverter_sensor?

    Sensor::Config.inverter_sensors.map(&:name)
  end

  def inverter_sensor?
    Sensor::Config.inverter_sensors.map(&:name).include?(sensor.name)
  end

  def specific_yield_sensor
    sensor.name == :inverter_power ? [:specific_yield] : []
  end

  def house_power_excluded_sensors
    return [] unless sensor.name == :house_power

    Sensor::Config.house_power_excluded_sensors.map(&:name)
  end

  def grid_sensor
    grid_sensor_name = :"#{sensor.name}_grid"
    return [] unless power_splitter_sensor?(grid_sensor_name)

    [grid_sensor_name]
  end

  def power_splitter_sensor?(sensor_name)
    Sensor::Registry
      .by_category(:power_splitter)
      .map(&:name)
      .include?(sensor_name)
  end

  def battery_sensors
    if sensor.name == :battery_power
      %i[battery_charging_power battery_discharging_power]
    else
      []
    end
  end

  def grid_power_sensors
    sensor.name == :grid_power ? %i[grid_import_power grid_export_power] : []
  end

  def grid_power_cost_sensors
    return [] unless sensor.name == :grid_power
    return [] unless ApplicationPolicy.power_splitter?

    %i[grid_costs grid_revenue]
  end

  def cost_sensors
    return [] unless ApplicationPolicy.power_splitter?
    return [] unless sensor_supports_costs?

    costs_sensor_name = cost_sensor_name_for(sensor.name)
    unless Sensor::Config.exists?(costs_sensor_name, check_policy: false)
      return []
    end

    [costs_sensor_name]
  end

  def sensor_supports_costs?
    %i[
      wallbox_power
      heatpump_power
      house_power
      house_power_without_custom
      battery_power
    ].include?(sensor.name) || sensor.name.to_s.start_with?('custom_')
  end

  def cost_sensor_name_for(sensor_name)
    if sensor_name == :battery_power
      :battery_charging_costs
    else
      "#{sensor_name}_costs".sub('_power', '').to_sym
      # Example: custom_01_costs, house_without_custom_costs, wallbox_costs, ...
    end
  end

  def build_inverter_sensor_data
    active_sensors =
      (
        Sensor::Config.inverter_sensors.map(&:name) - [:inverter_power]
      ).select { |sensor_name| data.public_send(sensor_name)&.positive? }

    total_value =
      active_sensors.sum { |sensor_name| data.public_send(sensor_name) || 0 }

    active_sensors.map do |sensor_name|
      sensor_value = data.public_send(sensor_name)

      {
        name: sensor_name,
        value: sensor_value,
        percentage: percentage(sensor_value, total_value),
      }
    end
  end

  def percentage(value, total)
    return 0 unless total.positive?

    (value * 100.0 / total).round
  end
end
