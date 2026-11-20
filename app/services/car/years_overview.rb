# The overview of the car page for the whole time (see TrendOverview::Years),
# for the selected car, for all cars or for the guest sessions. A chart of
# the page has no daily value of its own, so each year takes its value from
# one report of the whole time (Car::Report), like a column of the chart of
# the page. The years start with the first car or guest session.
class Car::YearsOverview < TrendOverview::Years
  include Car::OverviewPage

  def initialize(timeframe:, car:)
    super(page: :cars, timeframe:)
    @selection = CarSelection.new(car, timeframe:, guest: true)
  end

  private

  def values_of(sensor)
    year_dates.transform_values { report.value(sensor.name, dates: it) }
  end

  def years = @years ||= year_dates.keys

  # The dates of each year, from the year of the first car or guest session
  def year_dates
    @year_dates ||= first_date ? report.date_ranges(by: :year, from: first_date) : {}
  end

  def first_date_of(_sensor) = first_date

  def report
    @report ||= selection.report(timeframe)
  end
end
