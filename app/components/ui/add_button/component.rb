# The button for a new entry of a list on the desktop: a plus on the header,
# where a phone has the action of Ui::TitleBar::Component. It opens the form
# in the modal and hides itself below lg. The label names the new entry for
# the tooltip and for a screen reader.
#
#   = render Ui::AddButton::Component.new(href: new_settings_price_path, label: 'New price')
class Ui::AddButton::Component < ViewComponent::Base
  # The look and the height of the other buttons on the header, like the car
  # filter of the charging sessions
  BASE_CLASS =
    'hidden lg:flex size-9 shrink-0 items-center justify-center rounded-md click-animation ' \
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-300 dark:focus-visible:ring-gray-400 ' \
    "#{Ui::Dropdown::Component::HEADER_BUTTON_CLASS}".freeze
  private_constant :BASE_CLASS

  def initialize(href:, label:)
    super()
    @href = href
    @label = label
  end

  def call
    link_to @href,
            class: BASE_CLASS,
            title: @label,
            'aria-label': @label,
            data: { turbo_frame: 'modal', controller: 'tooltip modal-launcher' } do
      icon('plus')
    end
  end
end
