# The figures and the trends of a chart of the car page: the value of the
# timeframe, its change against the previous month and the previous year (see
# Car::Trend), the day with the highest value, and for a rate and the maximum
# range the best and the worst period of the same kind (see Car::Spans). The
# overview shows the place of a rate in this span, and the insights lead to
# its ends. `car` is the selection of the car page (see CarSelection).
class Car::Insights::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:, car:)
    super()
    @sensor = sensor
    @timeframe = timeframe
    @selection = CarSelection.new(car, timeframe:, guest: true)
  end

  attr_reader :sensor, :timeframe, :selection

  # Nil without a value, for example without a rate
  def value
    return @value if defined?(@value)

    @value = report.value(sensor.name)
  end

  # The value for the heading of the sheet, like Insights::Component
  def heading_total
    return unless value

    Insights::HeadingTotal::Component.new(
      total: Sensor::Value::Component.new(value, sensor.name, context: :total, scaling: :kilo),
      running: (timeframe.year? || timeframe.month?) && timeframe.current?,
    )
  end

  # [date, value] of the day with the highest value, nil for a day
  def maximum
    return @maximum if defined?(@maximum)

    @maximum = (report.maximum(sensor.name) if timeframe.days_passed > 1)
  end

  # The car page of the day, with the timeline of the day in place of a chart
  def day_path(date) = helpers.cars_home_path(timeframe: date.to_s, car: selection.to_param)

  # The previous month only for a month, like Insights
  def trends
    @trends ||= {
      previous_month: (trend(:previous_period) if timeframe.month_like?),
      previous_year: trend(:previous_year),
    }.compact
  end

  # The spans of the charts, with the end that is good: a low rate, a high
  # range
  SPANS = {
    car_cost_rate: %i[cost_per_100km min],
    car_consumption_rate: %i[consumption_per_100km min],
    car_max_range: %i[max_range max],
  }.freeze
  private_constant :SPANS

  # [[key, value, timeframe], ...] of the best and the worst period, empty
  # without a span. The shown period can be an end.
  def span_ends
    key, best = SPANS[sensor.name]
    span = report.spans&.public_send(key) if key
    return [] unless span

    worst = best == :min ? :max : :min
    [[:best, best], [:worst, worst]].map { |name, extreme| [name, span.public_send(extreme), span.public_send(:"#{extreme}_timeframe")] }
  end

  def period_path(period) = helpers.cars_home_path(sensor_name: sensor.name, timeframe: period.to_s, car: selection.to_param)

  def trend_path(trend)
    helpers.cars_home_path(sensor_name: sensor.name, timeframe: trend.base_timeframe.to_s, car: selection.to_param)
  end

  private

  def report
    @report ||= Car::Report.new(timeframe, cars, guest: selection.with_guest?)
  end

  # "All" compares the cars of the installation, each in its period of use, so
  # a car that replaced another one continues its trend. The guest sessions
  # have no car.
  def cars
    return [] if selection.guest?

    selection.car ? [selection.car] : selection.installed
  end

  def trend(base)
    return unless value && Trend.available_for?(sensor:, timeframe:)

    Car::Trend.new(sensor:, timeframe:, current_value: value, base:, cars:, guest: selection.with_guest?).then { it if it.base_value }
  end
end
