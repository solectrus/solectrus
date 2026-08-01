# Info icon with a rich-HTML tooltip, used wherever a figure needs a sentence of
# explanation without spending layout on it. The hint text is split into
# paragraphs on blank lines (\n\n), so long hints stay readable.
#
# The tooltip controller sits on the wrapper, not on the <i>: Font Awesome
# replaces the <i> with an <svg> and discards its children, so the hidden
# html-target must be a sibling of the icon. The wrapper also carries the
# positioning, so it has a real bounding box for the tooltip to anchor to.
class InfoIcon::Component < ViewComponent::Base
  def initialize(text:, position: 'absolute bottom-2 right-2')
    super()
    @text = text
    @position = position
  end

  attr_reader :text, :position

  def wrapper_class
    "#{position} cursor-help"
  end

  def paragraphs
    text.split("\n\n")
  end
end
