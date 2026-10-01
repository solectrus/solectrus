# @label InfoIcon
# @logical_path general
class InfoIconComponentPreview < ViewComponent::Preview
  # @!group Overview

  # The default position: the bottom right corner of a tile.
  def in_tile
    render_with_template(locals: { text: 'A short explanation of the figure.' })
  end

  # A blank line in the text starts a new paragraph in the tooltip.
  def with_paragraphs
    render InfoIcon::Component.new(
             text: "The first paragraph.\n\nThe second paragraph, after a blank line.",
             position: 'inline-block',
           )
  end

  # @!endgroup
end
