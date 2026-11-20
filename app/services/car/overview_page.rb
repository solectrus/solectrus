# What both overviews of the car page share (Car::ChangesOverview,
# Car::YearsOverview): the selection of the page (see CarSelection), which
# each link keeps, and the rows, which follow the columns of the page
# (Car::Section).
module Car::OverviewPage
  attr_reader :selection

  def link_params = super.merge(car: selection.to_param)

  private

  def sensor_names
    @sensor_names ||= Car::Section::CHARTS.values.flatten & TrendOverview.page_sensor_names(:cars)
  end

  def group_of(sensor) = Car::Section.of(sensor.name)

  def cars = selection.report_cars

  # The first day of use of the cars, the same for each row
  def first_date
    return @first_date if defined?(@first_date)

    @first_date = Car::Trend.first_day_of_use(cars:, guest: selection.with_guest?)
  end
end
