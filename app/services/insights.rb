class Insights # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe

  def value
    return unless calculator.respond_to?(sensor)

    @value ||= calculator.public_send(sensor).to_f
  end

  def costs
    if %i[
         wallbox_power
         heatpump_power
         house_power
         house_power_without_custom
         battery_power
       ].exclude?(sensor) && !sensor.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field =
      if sensor == :battery_power
        'battery_charging_costs'
      else
        "#{sensor}_costs".sub('_power', '')
        # Example: custom_01_costs,  house_without_custom_costs, wallbox_costs, ...
      end

    calculator.public_send(costs_field)
  end

  def sensors_with_grid_ratio
    %i[
      wallbox_power
      heatpump_power
      house_power
      battery_power
      house_power_without_custom
    ] + SensorConfig.x.existing_custom_sensor_names
  end

  def power_grid_ratio
    return unless sensor.in?(sensors_with_grid_ratio)

    if sensor == :battery_power
      calculator.battery_charging_power_grid_ratio
    else
      calculator.public_send(:"#{sensor}_grid_ratio")
    end
  end

  def multi_inverter?
    SensorConfig.x.multi_inverter? && ApplicationPolicy.multi_inverter?
  end

  def inverter_sensor_values
    return unless multi_inverter?

    @inverter_sensor_values ||= build_inverter_sensor_data
  end

  def per_day_value
    return if timeframe.day?

    calculator.per_day(value)
  end

  def feed_in_revenue
    calculator.got
  end

  def grid_costs
    calculator.paid.abs
  end

  delegate :solar_price,
           :inverter_power_per_kwp,
           :battery_charging_power,
           :battery_discharging_power,
           to: :calculator

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

  private

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

  def calculator
    @calculator ||=
      Calculator::Range.new(timeframe, calculations: required_calculations)
  end

  def required_sensors
    base = []
    base += [sensor] if sensor.in?(SensorConfig::SENSOR_NAMES)
    base += SensorConfig.x.inverter_sensor_names if SensorConfig.x.inverter?(
      sensor,
    )
    base += SensorConfig.x.excluded_sensor_names if sensor == :house_power
    if :"#{sensor}_grid".in?(SensorConfig::POWER_SPLITTER_SENSORS)
      base += [:"#{sensor}_grid"]
    end
    base += %i[battery_charging_power battery_discharging_power] if sensor ==
      :battery_power
    base += %i[grid_import_power grid_export_power] if sensor == :grid_power

    base.uniq
  end

  def required_calculations
    required_sensors.map do |sensor_name|
      Queries::Calculation.new(sensor_name, :sum, :sum)
    end
  end

  def build_inverter_sensor_data
    active_sensors =
      (
        SensorConfig.x.inverter_sensor_names - [:inverter_power]
      ).select { |sensor_name| calculator.public_send(sensor_name)&.positive? }

    total_value =
      active_sensors.sum do |sensor_name|
        calculator.public_send(sensor_name) || 0
      end

    active_sensors.map do |sensor_name|
      sensor_value = calculator.public_send(sensor_name)

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
