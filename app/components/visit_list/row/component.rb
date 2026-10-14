# One visit of the list: a row of the table on the desktop, a cell of a list
# in the style of iOS on a phone (see Ui::TableRow::Component). Each opens the
# form of the place.
class VisitList::Row::Component < ViewComponent::Base
  include VisitTexts

  # The columns of the cell of a phone, by the number of icon columns: the
  # icons, the place, the duration and the chevron. The times below take the
  # columns of the place and the duration, so long times leave the place its
  # room.
  PHONE_COLUMNS = %w[
    max-lg:grid-cols-[minmax(0,1fr)_auto_auto]
    max-lg:grid-cols-[auto_minmax(0,1fr)_auto_auto]
    max-lg:grid-cols-[auto_auto_minmax(0,1fr)_auto_auto]
  ].freeze
  private_constant :PHONE_COLUMNS

  def initialize(visit:, context:)
    super()
    @visit = visit
    @context = context
  end

  attr_reader :visit, :context

  def phone_columns = PHONE_COLUMNS[context.icon_columns]

  # The form of the place leads back to this list
  def edit_path
    helpers.edit_settings_place_path(visit.place, return_to: context.list_path)
  end
end
