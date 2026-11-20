# The overview of a month or a year of the car page (see
# TrendOverview::Changes), for the selected car, for all cars or for the
# guest sessions. A chart of the page has no daily value of its own, so both
# periods take their values from a report of the cars (Car::Report), one
# report for each period.
class Car::ChangesOverview < TrendOverview::Changes
  include Car::OverviewPage

  def initialize(timeframe:, base:, car:)
    super(page: :cars, timeframe:, base:)
    @selection = CarSelection.new(car, timeframe:, guest: true)
  end

  private

  def trend_for(sensor)
    Car::Trend.new(
      sensor:,
      timeframe:,
      current_value: report.value(sensor.name),
      base:,
      base_data: base_report,
      first_date:,
    )
  end

  # The days that compare (see Trend.compared_timeframe)
  def report
    @report ||= selection.report(Trend.compared_timeframe(timeframe))
  end

  def base_report
    @base_report ||= selection.report(base_timeframe)
  end
end
