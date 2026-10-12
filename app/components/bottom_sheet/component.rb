# A sheet in the manner of iOS: on a phone it slides up from the lower edge,
# on a larger screen it stands in the middle as a dialog. utils/bottomSheet.ts
# opens and closes it, and closes it on a swipe down, on a tap beside it and
# on Escape. The look lives beside this file, in component.css.
#
# Two kinds of content use it. TurboModal renders one per request, with a
# title and the content of the page. The layout renders one without content,
# which a tooltip fills on a phone (utils/tooltipSheet.ts).
class BottomSheet::Component < ViewComponent::Base
  renders_one :title

  # Width on a larger screen. Forms need the room, running text does not: a
  # narrow panel keeps a line below ~65 characters. Lists with a chart take
  # the width between.
  WIDTHS = {
    narrow: 'md:max-w-xl',
    medium: 'md:max-w-2xl',
    wide: 'md:max-w-3xl',
  }.freeze
  private_constant :WIDTHS

  def initialize(id:, width: :wide, data: {})
    super()
    @id = id
    @width = WIDTHS[width]
    @data = data
  end

  attr_reader :id, :data

  def dialog_attributes
    {
      id:,
      class: 'bottom-sheet',
      'aria-labelledby': (title_id if title?),
      data:,
    }
  end

  def title_id
    "#{id}-title"
  end

  def panel_class
    ['bottom-sheet-panel', @width]
  end
end
