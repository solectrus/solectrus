class Insights::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:, controller_namespace:)
    super()
    @insights = Insights.new(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
    @controller_namespace = controller_namespace
  end

  attr_reader :sensor, :timeframe, :insights, :controller_namespace

  delegate :data, to: :insights

  # Everyone sees what the tooltip of a balance segment shows: the total and
  # the values beside it. The figures beyond it need this permission.
  def permitted?
    ApplicationPolicy.insights?
  end

  # The values of the tooltip, for a sensor and a period that a page shows the
  # user. Without the permission, a sensor that needs a permission of its own,
  # a sensor that only a page with a permission shows, or a relative period
  # (SponsoredFrame) has none.
  def tooltip_values?
    return @tooltip_values if defined?(@tooltip_values)

    @tooltip_values =
      permitted? ||
        (
          permitted_timeframe? && sensor.permitted? &&
            Sensor::HomePage.shown?(sensor.name)
        )
  end

  def per_day_value?
    return false if timeframe.days_passed <= 1
    return false unless sensor.allowed_aggregations.first == :sum

    %i[grid_power wallbox_power battery_soc battery_power].exclude?(sensor.name)
  end

  # A year or a month that still runs, so its values still grow
  def running_period?
    (timeframe.year? || timeframe.month?) && timeframe.current?
  end

  # The total of the period, which the heading of the sheet shows
  # (insights/index.html.slim)
  def total_value
    case sensor.name
    when :inverter_power
      SensorValue::Component.new(data, sensor.name, context: :total, precision: 3)
    when :house_power, :wallbox_power, :heatpump_power
      SensorValue::Component.new(data, sensor.name, context: :total, scaling: :kilo)
    else
      return unless sensor.allowed_aggregations.first == :sum

      SensorValue::Component.new(insights.value, sensor.name, context: :total, scaling: :kilo)
    end
  end

  # The strings show their values with the decimals of the largest one, so a
  # small value reads "2 kWh" below "5.831 kWh", not "1,7 kWh"
  def inverter_precision
    @inverter_precision ||= begin
      largest = insights.inverter_sensor_values.max_by { it[:value].to_f }

      Sensor::ValueFormatter.new(
        largest[:value],
        unit: Sensor::Registry[largest[:name]].unit,
        context: :total,
        scaling: :kilo,
      ).precision
    end
  end

  # The total for the heading of the sheet
  def heading_total
    return unless tooltip_values?
    return unless (total = total_value)

    Insights::HeadingTotal::Component.new(total:, running: running_period?)
  end

  # The share of PV and grid, and the costs it causes. A consumer shows the
  # share also without prices. The battery has a grid share but no costs of
  # its own: what it stores is billed to the consumers taking it back out.
  def splitted_costs
    return splitted_costs_with_prices if insights.custom_power_sensor?

    case sensor.name
    when :house_power, :wallbox_power, :heatpump_power
      splitted_costs_with_prices
    when :inverter_power
      splitted_costs_with_prices if insights.costs
    when :battery_power, :battery_charging_power
      if insights.power_grid_ratio
        SplittedCosts::Component.new(power_grid_ratio: insights.power_grid_ratio, note: insights.costs_note)
      end
    end
  end

  def days(count)
    "#{count} #{count == 1 ? t('.day') : t('.days')}"
  end

  def battery_soc_longest_streak_path
    from, to, = insights.battery_soc_longest_streak.values
    return unless from && to
    return if to <= from

    url_for(
      sensor_name: 'battery_soc',
      timeframe: "#{from}..#{to}",
      controller: "#{controller_namespace}/home",
    )
  end

  def yearly_trend_base_path
    url_for(
      sensor_name: sensor.name,
      timeframe: insights.yearly_trend.base_timeframe.to_s,
      controller: "#{controller_namespace}/home",
    )
  end

  def monthly_trend_base_path
    url_for(
      sensor_name: sensor.name,
      timeframe: insights.monthly_trend.base_timeframe.to_s,
      controller: "#{controller_namespace}/home",
    )
  end

  def day_path(day)
    url_for(
      sensor_name: sensor.name,
      timeframe: day,
      controller: "#{controller_namespace}/home",
    )
  end

  private

  def permitted_timeframe?
    !timeframe.relative? || ApplicationPolicy.relative_timeframe?
  end

  def splitted_costs_with_prices
    SplittedCosts::Component.new(
      power_grid_ratio: insights.power_grid_ratio,
      costs: insights.costs,
      grid_costs: insights.costs_grid,
      pv_costs: insights.costs_pv,
    )
  end
end
