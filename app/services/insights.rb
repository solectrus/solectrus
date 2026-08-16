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

  # The battery is missing on purpose: it has no costs of its own. What is
  # charged into it from the grid is billed to the consumers that take it back
  # out again, through their own grid share.
  #
  # Rendered several times by the template, so this and #power_grid_ratio
  # memoize -- their lookups walk the whole summary.
  def costs
    return @costs if defined?(@costs)

    @costs =
      if sensor_supports_costs? && ApplicationPolicy.power_splitter?
        data.public_send(costs_sensor_name)
      end
  end

  def costs_grid
    costs_by_source(:grid)
  end

  def costs_pv
    costs_by_source(:pv)
  end

  def sensors_with_grid_ratio
    @sensors_with_grid_ratio ||=
      %i[
        wallbox_power
        heatpump_power
        house_power
        house_power_without_custom
        battery_power
      ] + Sensor::Config.custom_power_sensors.map(&:name)
  end

  # battery_power stands for both directions, and its grid ratio is the one of
  # the charging: that is where grid electricity enters the battery. The
  # discharge has a ratio of its own, but it is an attribution from the Power
  # Splitter's ledger rather than something the battery does at that moment.
  def power_grid_ratio
    return @power_grid_ratio if defined?(@power_grid_ratio)

    @power_grid_ratio =
      if sensor.name == :battery_power
        data.battery_charging_power_grid_ratio
      elsif sensor.name.in?(sensors_with_grid_ratio)
        data.public_send(:"#{sensor.name}_grid_ratio")
      end
  end

  # The battery has a grid share but no costs of its own (see #costs), so say
  # where that money went instead. Only worth saying while there is a grid
  # share to talk about.
  def costs_note
    return unless sensor.name == :battery_power
    return unless power_grid_ratio&.positive?

    I18n.t('splitter.costs_note.battery_charging_power')
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
      # A combined chart draws two sensors, so both belong to the insights.
      *sensor.chart_partner_names,
      *battery_grid_sensor,
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

  # The grid share feeds #power_grid_ratio. An older Power Splitter reports
  # none, and the ratio then stays nil.
  def battery_grid_sensor
    return [] unless sensor.name == :battery_power
    return [] unless Sensor::Config.exists?(:battery_charging_power_grid)

    [:battery_charging_power_grid]
  end

  def grid_power_cost_sensors
    return [] unless sensor.name == :grid_power
    return [] unless ApplicationPolicy.power_splitter?

    %i[grid_costs grid_revenue]
  end

  def cost_sensors
    return [] unless ApplicationPolicy.power_splitter?
    return [] unless sensor_supports_costs?
    unless Sensor::Config.exists?(costs_sensor_name, check_policy: false)
      return []
    end

    [costs_sensor_name]
  end

  # Example: custom_01_costs, house_without_custom_costs, wallbox_costs, ...
  def costs_sensor_name
    "#{sensor.name}_costs".sub('_power', '').to_sym
  end

  def sensor_supports_costs?
    %i[
      wallbox_power
      heatpump_power
      house_power
      house_power_without_custom
    ].include?(sensor.name) || sensor.name.to_s.start_with?('custom_')
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
