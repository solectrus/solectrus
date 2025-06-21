class Insights::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:)
    super
    @insights = Insights.new(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe, :insights

  def icon_class
    case sensor
    when :grid_power, :grid_export_power, :grid_import_power
      'fa-bolt'
    when :inverter_power
      'fa-sun'
    when :battery_power, :battery_discharging_power, :battery_charging_power
      'fa-battery-half'
    when :house_power
      'fa-home'
    when :heatpump_power
      'fa-fan'
    when :wallbox_power
      'fa-car'
    end
  end

  def per_day_value?
    %i[
      inverter_power
      grid_import_power
      grid_export_power
      wallbox_power
      battery_soc
    ].exclude?(sensor)
  end

  def battery_soc_longest_streak_path
    from, to, = insights.battery_soc_longest_streak.values

    root_path(sensor: 'battery_soc', timeframe: "#{from}..#{to}")
  end

  def yearly_trend_base_path
    root_path(sensor:, timeframe: insights.yearly_trend.base_timeframe.to_s)
  end

  def monthly_trend_base_path
    root_path(sensor:, timeframe: insights.monthly_trend.base_timeframe.to_s)
  end
end
