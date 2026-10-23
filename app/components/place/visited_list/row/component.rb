# One place of the list (see Place::VisitedList::Component): a row of the table
# from lg up, a cell of a grouped list below. The row opens the place with its
# map, like a row of the visits, and the number of the visits opens them.
class Place::VisitedList::Row::Component < ViewComponent::Base
  def initialize(place:, cars:, visit_count:, last_started_at:, visits_href:)
    super()
    @place = place
    @cars = cars
    @visit_count = visit_count
    @last_started_at = last_started_at
    @visits_href = visits_href
  end

  attr_reader :place, :cars, :visit_count, :visits_href

  # The form of the place, which keeps the address of the list
  def href = helpers.edit_settings_place_path(place, return_to: helpers.list_address)

  # The day of the latest visit: today, yesterday, or its date
  def last
    date = @last_started_at.in_time_zone.to_date
    if date == Date.current then t('.today')
    elsif date == Date.yesterday then t('.yesterday')
    else l(date, format: date.year == Date.current.year ? :short : :default)
    end
  end
end
