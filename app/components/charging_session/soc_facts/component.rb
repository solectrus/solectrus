# The state of charge and the loss of a charge, in the form of a session:
# "Charge level 23 -> 81 % - about 9 % loss (rough estimate)". A state of
# charge that does not fit the charged energy gets an explanation in place of
# the loss. Nothing without a state of charge.
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
    tag.p(class: @css_class) do
      line = [t('charging_sessions.soc', range: soc_range), remark].compact.join(' · ')
      finding ? safe_join([line, tag.span(t("charging_sessions.soc_finding.#{finding}.hint"), class: 'block')]) : line
    end
  end

  private

  # :mismatch for a state of charge that contradicts the energy,
  # :above_energy for one that rose more than the energy explains, or nil
  # (see ChargingSession::StateOfCharge)
  def finding
    return @finding if defined?(@finding)

    @finding =
      if charging_session.soc_mismatch?
        :mismatch
      elsif charging_session.loss&.negative?
        :above_energy
      end
  end

  def remark
    return t("charging_sessions.soc_finding.#{finding}.text") if finding

    loss = charging_session.loss
    t('charging_sessions.loss', percent: number_to_percentage(loss * 100, precision: 0)) if loss
  end
end
