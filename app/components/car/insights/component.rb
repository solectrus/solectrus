# The figures and the trends of a chart of the car page: the value of the
# timeframe, its change against the previous month and the previous year (see
# Car::Trend), and the day with the highest value. `car` is the selection of
# the car page (see CarSelection).
class Car::Insights::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:, car:)
    super()
    @sensor = sensor
    @timeframe = timeframe
    @selection = CarSelection.new(car, timeframe:)
  end

  attr_reader :sensor, :timeframe, :selection

  # Nil without a value, for example without a rate
  def value
    return @value if defined?(@value)

    @value = report.value(sensor.name)
  end

  # [date, value] of the day with the highest value, nil for a day
  def maximum
    return @maximum if defined?(@maximum)

    @maximum = (report.maximum(sensor.name) if timeframe.days_passed > 1)
  end

  # The car page of the day. The driving cost has no chart of a day, so the
  # distance.
  def day_path(date)
    sensor_name = sensor.name == :car_driving_costs ? :car_distance : sensor.name
    helpers.cars_home_path(sensor_name:, timeframe: date.to_s, car: selection.to_param)
  end

  # The previous month only for a month, like Insights
  def trends
    @trends ||= {
      previous_month: (trend(:previous_period) if timeframe.month_like?),
      previous_year: trend(:previous_year),
    }.compact
  end

  def trend_path(trend)
    helpers.cars_home_path(sensor_name: sensor.name, timeframe: trend.base_timeframe.to_s, car: selection.to_param)
  end

  private

  def report
    @report ||= Car::Report.new(timeframe, cars)
  end

  # "All" compares the cars of the installation, each in its period of use, so
  # a car that replaced another one continues its trend
  def cars = selection.car ? [selection.car] : selection.installed

  def trend(base)
    return unless value && Trend.available_for?(sensor:, timeframe:)

    Car::Trend.new(sensor:, timeframe:, current_value: value, base:, cars:).then { it if it.base_value }
  end
end
