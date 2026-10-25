# The header of a group of rows in a list, like the month of the charging
# sessions (see Timeframe::RowGroups). It spans the table on the desktop and
# cuts the card of a phone into a card per group (see component.css). With
# `href`, it links to the list of the group alone.
#
#   = render Ui::GroupHeader::Component.new(title: 'March 2026', href: list_path(month))
class Ui::GroupHeader::Component < ViewComponent::Base
  def initialize(title:, href: nil)
    super()
    @title = title
    @href = href
  end

  attr_reader :title, :href
end
