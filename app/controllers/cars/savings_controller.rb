# The comparison of the cars with a combustion car on a page of its own (see
# Car::Comparison): the savings, the calculation of each column, the periods
# of the timeframe and the payments. Like the lists below the car page, the
# page has a timeframe and a car select (see Car::SubNav::Component). The
# menu and the page More link to it (see MainNavigation#car_pages).
class Cars::SavingsController < ApplicationController
  include CarListPage

  # Like the car page, the comparison is open to everyone. Only the admin
  # opens the payments behind its numbers (see Car::ComparisonLinks).
  skip_before_action :admin_required!

  # Without fuel prices, there is no comparison (see
  # Car::Comparison.available?), so the page leads to the car page
  before_action { redirect_to(cars_home_path) unless Car::Comparison.available? }

  # The page comes first without the comparison, so its frame is on screen at
  # once. Its frame then asks the same address for the comparison, which takes
  # the time (see Ui::LazyFrame).
  def index
    # A car that the page does not offer goes to "all", like on the car page
    return redirect_to(page_path_with(car: nil)) unless car_selection.valid?
    # The live view and the last hours go to today
    return redirect_to(page_path_with) unless Car::Comparison.timeframe?(timeframe)
    return render(:comparison) if turbo_frame_request?

    # While days wait for the build, the page shows the build instead of the
    # comparison. Like the car page, it builds a few days at once.
    @pending_days = Sensor::Summarizer.build_few(Car::Report.pending_days(timeframe))
  end

  private

  # Like the car page, a visitor without the admin login sees the data up
  # to the latest public day, so the savings are the same as below its
  # driving (see Cars::Selectable#data_timeframe)
  helper_method def report
    @report ||= Car::Report.new(admin? ? timeframe : Car::AdminOnlyDays.public_timeframe(timeframe), car_selection.cars)
  end

  # Whether the report of such a visitor leaves out the days that only the
  # admin sees, which a note above the comparison says
  helper_method def admin_only_days_left_out? = !admin? && Car::AdminOnlyDays.overlap?(timeframe)

  # Like Cars::Selectable, but without its selection_params, which would
  # change the timeframe navigation and the frame id of the comparison
  helper_method def car_selection
    @car_selection ||= CarSelection.new(params[:car], timeframe:)
  end

  # The selected car, or nil for "all"
  helper_method def car = car_selection.car

  helper_method def car_select?
    Car.configured.many?
  end

  helper_method def car_select_component(**)
    Car::Select::Component.new(cars: car_selection.offered, car:, path: ->(id) { page_path_with(car: id) }, **)
  end

  # The page with the changes, for a link to the page in another timeframe or
  # with another car. The car stays also as nil for "all", because Rails
  # takes a missing car from the current address. The comparison takes a
  # live view and the last hours as today (see Car::Comparison.timeframe),
  # and the whole time has no timeframe in the address.
  helper_method def page_path_with(**changes)
    timeframe = Car::Comparison.timeframe(self.timeframe)
    query = { car: car_selection.to_param, **changes }
    cars_savings_path(timeframe: (timeframe.to_param unless timeframe.all?), **query)
  end

  # The select offers the timeframes of whole days
  helper_method def timeframe_page
    TimeframePage::List.new(route: :cars_savings_path, params: { car: car_selection.to_param }, kinds: Car::Comparison::TIMEFRAME_KINDS)
  end

  # The tab of this page (see CarListPage#list_tabs)
  def list_tab = :savings

  # The car page in the timeframe and with the car of the page
  helper_method def back_path
    cars_home_path(sensor_name: nil, timeframe: timeframe.to_param, car: car_selection.to_param)
  end

  # The title bar of a phone has the name of the menu and of the page More,
  # so the page slides in with it. The desktop names the page in its tab.
  helper_method def title
    t('layout.car_comparison')
  end
end
