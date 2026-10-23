# One visit of the list: a row of the table on the desktop, a cell of a
# grouped list on a phone (see Ui::TableRow::Component). Each opens the
# form of the place.
class Place::VisitList::Row::Component < ViewComponent::Base
  include Place::VisitTexts

  def initialize(visit:, context:)
    super()
    @visit = visit
    @context = context
  end

  attr_reader :visit, :context

  def date = l(visit.started_at.in_time_zone.to_date, format: :weekday)

  # The times of the visit. The list of one day names the times on the day,
  # and after them a start or an end outside it.
  def times
    return time_range unless context.timeframe.day?

    line, note = day_times(context.timeframe.effective_beginning_date)
    [line, note].compact.join(', ')
  end

  # The line below the place on a phone: the day, the times and, with more
  # than one car, the car
  def phone_line = [date, times, (visit.car.display_name if context.car_column?)].compact.join(' · ')

  # The form of the place leads back to this list
  def edit_path
    helpers.edit_settings_place_path(visit.place, return_to: helpers.list_address)
  end
end
