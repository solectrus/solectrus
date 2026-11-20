# The figures of a chart of the car page in a period beside those of an
# earlier one, like Insights::Comparison, for the selected car. The chart
# has no daily value of its own, so both periods come from a report of the
# cars (Car::Report). It has no figures of the days, only the day with the
# highest value, and a calendar of the months for the whole time.
class Insights::CarComparison < Insights::Comparison
  # { year => { month => value } } of the months with a value, from the
  # year of the first car or guest session, for the whole time alone
  def heatmap_data
    return @heatmap_data if defined?(@heatmap_data)
    return @heatmap_data = nil unless timeframe.all?

    @heatmap_data = (first_date ? current.date_ranges(by: :month, from: first_date) : {}).each_with_object({}) do |(month, dates), data|
      value = current.value(sensor.name, dates:)
      (data[month.year] ||= {})[month.month] = value if value
    end.presence
  end

  # The charging has the color of the wallbox in place of a color of its
  # own, as in its chart, and each link keeps the selected car
  def heatmap_tile
    { color: (Car::ChargingSource[:wallbox].color_class unless sensor.color_background), link_params: { car: car_param } }
  end

  def days = []

  # [key, day, value] of the day with the highest value, none for a rate
  def extremes
    day, value = current.maximum(sensor.name)
    day ? [[:maximum, day, value]] : []
  end

  # The selection of the car page, which each link keeps
  def car_param = selection.to_param

  private

  def source(frame) = selection.report(frame)

  def selection = @selection ||= CarSelection.new(@car, timeframe:, guest: true)

  # The first day of use of the selected cars, as in the overview
  def first_date
    return @first_date if defined?(@first_date)

    @first_date = Car::Trend.first_day_of_use(cars: selection.report_cars, guest: selection.with_guest?)
  end

  def value_of(report) = report.value(sensor.name)

  # Each month from the report of the period
  def monthly(report)
    report.date_ranges(by: :month).transform_values { report.value(sensor.name, dates: it) }.compact
  end
end
