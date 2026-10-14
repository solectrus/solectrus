# The button for a new session. A new session is an offsite session, the
# detection writes the others, so only the offsite list has it. An offsite
# session needs a car. `css_class` places the Ui::AddButton::Component, and
# a phone has the action of the title bar instead.
class ChargingSession::AddButton::Component < ViewComponent::Base
  def initialize(kind:, selection:, css_class: nil)
    super()
    @kind = kind
    @selection = selection
    @css_class = css_class
  end

  # Whether the list of the kind offers a new session
  def self.offered?(kind:, selection:) = kind == 'offsite' && selection.installed.any?

  def render? = self.class.offered?(kind: @kind, selection: @selection)

  # The form keeps the address of the list, with its timeframe and its car
  # filter
  def call
    render Ui::AddButton::Component.new(
      href: helpers.new_cars_charging_session_path(return_to: helpers.list_address),
      label: t('charging_sessions.new'),
      css_class: @css_class,
    )
  end
end
