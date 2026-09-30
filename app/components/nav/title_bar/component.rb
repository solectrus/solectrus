# The title bar of a page in a drill-down hierarchy on a phone, as on iOS: the
# title in the middle and, below the top level, a round back button to the
# parent page. The button carries no text, so the title keeps the middle on a
# narrow screen too.
#
# A change between such pages slides (see component.css). The controller finds
# the direction: a page whose parent is the current page slides in from the
# right, the way back to the parent slides out to the right.
class Nav::TitleBar::Component < ViewComponent::Base
  def initialize(title:, back_href: nil, back_label: nil)
    super()
    @title = title
    @back_href = back_href
    @back_label = back_label
  end

  attr_reader :title, :back_href, :back_label

  # Turbo runs a page change as a view transition only when both pages ask for
  # it. Every page with a title bar does, so the slide stays between them.
  #
  # No preview from the cache on a tap: the controller slides to a skeleton at
  # once, and a preview would cut that slide short. The back gesture of the
  # browser still restores from the cache.
  def before_render
    helpers.content_for(
      :head,
      tag.meta(name: 'view-transition', content: 'same-origin'),
    )
    helpers.turbo_exempts_page_from_preview
  end
end
