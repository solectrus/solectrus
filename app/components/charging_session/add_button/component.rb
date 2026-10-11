# The button for a new session. A new session is an offsite session, the
# detection writes the others, so only the offsite list has it. An offsite
# session needs a car. `css_class` gives the look and the place: desktop
# shows a round button on the edge of the header, mobile a wide one with a
# `label` above the list.
class ChargingSession::AddButton::Component < ViewComponent::Base
  def initialize(kind:, selection:, css_class:, label: false)
    super()
    @kind = kind
    @selection = selection
    @css_class = css_class
    @label = label
  end

  def render?
    @kind == 'offsite' && @selection.installed.any?
  end

  # The form takes no place of its own, so it does not count as an item of
  # a flex row
  def call
    helpers.button_to(
      helpers.new_cars_charging_session_path,
      method: :get,
      params: helpers.list_params,
      form_class: 'contents',
      data: { turbo_frame: 'modal', controller: 'modal-launcher' },
      class: ['items-center justify-center click-animation', @css_class],
      title: (t('charging_sessions.new') unless @label),
      'aria-label': (t('charging_sessions.new') unless @label),
    ) { safe_join([helpers.icon('plus'), (tag.span(t('charging_sessions.new')) if @label)]) }
  end
end
