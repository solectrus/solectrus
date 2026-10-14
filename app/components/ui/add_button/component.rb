# The round button for a new entry of a list on the desktop, a plus on the
# accent color. It opens the form in the modal. A phone has the action of
# Ui::TitleBar::Component for it, so the button hides itself below lg. The
# label names the new entry for the tooltip and for a screen reader.
#
# css_class places the button, like on the edge of the header:
#
#   = render Ui::AddButton::Component.new(href: new_settings_price_path, label: 'New price')
class Ui::AddButton::Component < ViewComponent::Base
  # The focus shows as an outline, so a ring of the placement stays free
  BASE_CLASS =
    'flex max-lg:hidden size-14 shrink-0 items-center justify-center rounded-full ' \
    'bg-indigo-600 dark:bg-indigo-800 text-white shadow-lg hover:bg-indigo-700 click-animation ' \
    'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500'.freeze
  private_constant :BASE_CLASS

  def initialize(href:, label:, css_class: nil)
    super()
    @href = href
    @label = label
    @css_class = css_class
  end

  def call
    link_to @href,
            class: [BASE_CLASS, @css_class],
            title: @label,
            'aria-label': @label,
            data: { turbo_frame: 'modal', controller: 'tooltip modal-launcher' } do
      icon('plus', class: 'fa-lg')
    end
  end
end
