# Info icon with a rich-HTML tooltip, used wherever a figure needs a sentence of
# explanation without spending layout on it. The hint text is split into
# paragraphs on blank lines (\n\n), so long hints stay readable.
#
# The tooltip controller sits on the wrapper, not on the <i>: Font Awesome
# replaces the <i> with an <svg> and discards its children, so the hidden
# html-target must be a sibling of the icon. The wrapper also carries the
# positioning, so it has a real bounding box for the tooltip to anchor to.
class InfoIcon::Component < ViewComponent::Base
  # Muted, unobtrusive - right for a corner of a stat tile, where the icon must
  # not compete with the figure. Callers placing it among real controls pass
  # their own so it carries the same weight as its neighbours.
  DEFAULT_ICON_CLASS = 'text-gray-400 dark:text-gray-500'.freeze
  public_constant :DEFAULT_ICON_CLASS

  def initialize(
    text:,
    position: 'absolute bottom-2 right-2',
    icon_class: DEFAULT_ICON_CLASS
  )
    super()
    @text = text
    @position = position
    @icon_class = icon_class
  end

  attr_reader :text, :position, :icon_class

  # cursor-help rather than the caller's cursor: this is a hover target, never
  # a click target, whatever shape it is given.
  def wrapper_class
    "#{position} cursor-help"
  end

  def full_icon_class
    "fa fa-circle-info font-normal normal-case #{icon_class}"
  end

  def paragraphs
    text.split("\n\n")
  end
end
