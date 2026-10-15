# The state of charge and the loss of a charge, in the form of a session:
# "Charge level 23 -> 81 % - 9 % loss". Nothing without a state of charge.
class ChargingSession::SocFacts::Component < ViewComponent::Base
  include ChargingSession::Texts

  def initialize(charging_session:, css_class: nil)
    super()
    @charging_session = charging_session
    @css_class = css_class
  end

  attr_reader :charging_session

  def render? = soc_range.present?

  def call
    tag.p([t('charging_sessions.soc', range: soc_range), loss].compact.join(' · '), class: @css_class)
  end

  private

  # See ChargingSession#loss
  def loss
    loss = charging_session.loss
    t('charging_sessions.loss', percent: number_to_percentage(loss * 100, precision: 0)) if loss
  end
end
