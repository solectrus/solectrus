# The header of a group of rows in a list (see Ui::RowGroups). It spans the
# table on the desktop and cuts the card of a phone into a card per group
# (see component.css). It links to the list of the group alone.
class Ui::GroupHeader::Component < ViewComponent::Base
  def initialize(group:, href:)
    super()
    @group = group
    @href = href
  end

  attr_reader :href

  # A day names its weekday alone, its rows show the date
  def title = @group.day? ? l(@group.date, format: '%A') : @group.localized
end
