# @label Nav::Bottom
# @logical_path navigation
# @display max_width 100%
#
# The bottom bar shows on phones and tablets. A landscape screen from the lg
# breakpoint on (1024px) hides it, and the preview pane is often that wide. So
# every variant renders in a frame of phone size. A tap on "More" opens the
# menu in the frame.
class NavBottomComponentPreview < ViewComponent::Preview
  VARIANTS = {
    'default' => { label: 'Four pages, the rest under More' },
    'current_in_menu' => { label: 'Open page under More', current: 5 },
    'helios' => { label: 'HELIOS needs action', helios_dot: true },
    'unread' => { label: 'Unread notifications', unread: 3 },
    'helios_and_unread' => {
      label: 'HELIOS and unread notifications',
      helios_dot: true,
      unread: 3,
    },
    'menu_open' => {
      label: 'Menu open',
      helios_dot: true,
      unread: 3,
      open: true,
    },
  }.freeze
  private_constant :VARIANTS

  # @label Phones
  def phones
    render_with_template(
      locals: {
        labels: VARIANTS.transform_values { it[:label] },
      },
    )
  end

  # One phone screen. The frames of the scenario above load it.
  # @hidden
  # @display bare true
  def phone(variant: 'default')
    options = VARIANTS[variant]
    unread = options.fetch(:unread, 0)

    render_with_template(
      locals: {
        items: NavPreviewItems.primary(current: options.fetch(:current, 0)),
        secondary_items:
          NavPreviewItems.secondary(
            helios_dot: options.fetch(:helios_dot, false),
            unread:,
          ),
        unread:,
        open: options.fetch(:open, false),
      },
    )
  end
end
