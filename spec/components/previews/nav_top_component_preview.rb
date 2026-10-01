# @label Nav::Top
# @logical_path navigation
# @display bare true
#
# The main navigation shows from the lg breakpoint on (1024px). Below it, only
# the band of the header and the sub navigation remain, and the bottom bar
# takes over (see Nav::Bottom). A narrow preview pane hides it, so widen the
# pane if it is empty.
class NavTopComponentPreview < ViewComponent::Preview
  # @!group Overview

  # @label Default
  def default
    header
  end

  # @label Unread notifications
  def unread
    header(unread: 3)
  end

  # @label HELIOS needs action
  def helios
    header(helios_dot: true)
  end

  # @!endgroup

  private

  def header(helios_dot: false, unread: 0)
    render_with_template(
      template: 'nav_top_component_preview/header',
      locals: {
        primary: NavPreviewItems.primary(current: 1),
        secondary: NavPreviewItems.secondary(helios_dot:, unread:),
        unread:,
      },
    )
  end
end
