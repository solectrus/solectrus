# A list below the car page: the charging sessions, the places and the visits.
# Only the admin sees it (see Cars::PageGate), unless the list allows a visitor, and
# it has a timeframe that defaults to the whole time. The lists of the
# charging sessions and of the places stand side by side as pills in the
# header of the desktop, with the savings against a combustion car (see
# #list_tabs).
module CarListPage
  extend ActiveSupport::Concern
  include Cars::PageGate
  include TimeframeSelectModal

  included do
    helper_method :timeframe, :list_tabs, :pager_items
  end

  private

  # The period of a phone, as the home pages have it (see
  # TimeframePagerItems). The whole time of a list has a name of its own.
  def pager_items
    TimeframePagerItems.new(
      timeframe:,
      path: ->(timeframe) { timeframe_page.path(timeframe) },
      period_item: (timeframe.all? ? { name: timeframe_page.label_for_all } : {}),
    ).to_h
  end

  # A closed car page sends its list to the start page, or to the car page
  # with its upsell
  def car_page_closed
    redirect_to(Sensor::HomePage.available?(:cars) ? cars_home_path : root_path)
  end

  def timeframe
    @timeframe ||= Timeframe.new(timeframe_param.presence || 'all')
  rescue ArgumentError
    @timeframe = Timeframe.new('all')
  end

  # The lists of the charging sessions and of the places, and the savings
  # against a combustion car, in the timeframe and with the car of this
  # page. Only a car with a location has places. The places and the savings
  # have no timeframe in the address for the whole time, and the savings
  # take a shorter timeframe as its year (see Car::Comparison.timeframe).
  # Without fuel prices, there are no savings (see
  # Car::Comparison.available?).
  # The controller names its own tab with #list_tab.
  def list_tabs
    car = car_selection.car&.id
    savings_timeframe = Car::Comparison.timeframe(timeframe)
    [
      { name: t('charging_sessions.title'), href: cars_charging_sessions_path(timeframe: timeframe.to_param, car: car_selection.to_param), current: list_tab == :charging_sessions },
      ({ name: t('car_breakdown.places'), href: cars_visited_places_path(timeframe: (timeframe.to_param unless timeframe.all?), car:), current: list_tab == :places } if Car.configured.any?(&:located?)),
      ({ name: t('car_comparison.tab'), href: cars_savings_path(timeframe: (savings_timeframe.to_param unless savings_timeframe.all?), car:), current: list_tab == :savings } if Car::Comparison.available?),
    ].compact
  end

  # The timeframe in the address of the list
  def timeframe_param = params[:timeframe]
end
