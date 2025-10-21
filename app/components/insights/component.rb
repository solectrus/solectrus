class Insights::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:)
    super()
    @insights = Insights.new(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe, :insights

  delegate :data, to: :insights

  def per_day_value?
    return false if timeframe.days_passed <= 1
    return false unless sensor.allowed_aggregations.first == :sum

    %i[grid_power wallbox_power battery_soc battery_power].exclude?(sensor.name)
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

  def controller_namespace
    if request.referer.include?('/house/')
      'house'
    elsif request.referer.include?('/inverter/')
      'inverter'
    elsif request.referer.include?('/heatpump/')
      'heatpump'
    else
      'balance'
    end
  end
end
