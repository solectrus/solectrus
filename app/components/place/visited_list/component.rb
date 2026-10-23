# The places of the cars in a timeframe below the chart of the page of the
# driving: each place with its cars, the number of its visits and its latest
# visit, the most visited place first. A table on the desktop, a grouped list
# on a phone. A row opens the visits of its place, and the list loads its
# pages one after the other (see Ui::LazyRows).
class Place::VisitedList::Component < ViewComponent::Base
  # `rows` are the rows of PlaceVisit.by_place. `visits_path` takes the id of
  # a place and gives its visits.
  def initialize(rows:, pagy:, visits_path:)
    super()
    @rows = rows
    @pagy = pagy
    @visits_path = visits_path
  end

  attr_reader :rows, :pagy, :visits_path

  # The columns of the table from lg up: the icon, the place, the cars, the
  # visits and the latest visit
  GRID_COLUMNS = 'lg:grid-cols-[auto_minmax(0,1fr)_auto_auto_auto]'.freeze
  public_constant :GRID_COLUMNS
end
