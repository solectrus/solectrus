# The place of the mark of an entry that an AI client wrote, at the end of
# the column of the date: a robot in the color of secondary text, because it
# tells the source and asks for nothing. The tooltip and a screen reader
# explain it.
#
# Each row of a list gets the place, so the column of the date is as wide in
# each row and the marks stand one below the other. The mark stays until the
# admin saves the entry (see Origin). Only the admin checks and saves an
# entry, so a visitor gets neither the mark nor its place.
class OriginBadge::Component < ViewComponent::Base
  # The width of the icon, at the end of a cell of flex
  CLASS = 'ms-auto inline-block w-5 shrink-0 text-muted'.freeze
  private_constant :CLASS

  def initialize(record:)
    super()
    @record = record
  end

  def render? = helpers.admin?

  def call
    return tag.span(class: CLASS, aria: { hidden: true }) unless @record.origin_mcp?

    tag.span(
      icon('robot'),
      class: CLASS,
      role: 'img',
      title: t('.title'),
      aria: { label: t('.title') },
      data: { controller: 'tooltip' },
    )
  end
end
