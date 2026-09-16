# @label PremiumStatus
class PremiumStatusComponentPreview < ViewComponent::Preview
  # Every state the box can show, with an end date where the state has one.
  # The countdown text decides whether a date appears, so a state without one
  # in its locale file ignores the date given here.
  SCENARIOS = [
    [:sponsoring, nil],
    [:sponsoring, 18.days],
    [:intro, 12.days],
    [:free_trial, 1.day],
    [:granted, 300.days],
    [:development, nil],
    [:locked_with_trial, nil],
    [:locked, nil],
    [:offline, nil],
  ].freeze
  private_constant :SCENARIOS

  # @!group Layouts

  # @label Menu on a phone (one line)
  def compact
    render_with_template(
      locals: {
        scenarios: scenarios,
        compact: true,
      },
    )
  end

  # @label Sidebar on a desktop (two lines)
  def wide
    render_with_template(
      template: 'premium_status_component_preview/compact',
      locals: {
        scenarios: scenarios,
        compact: false,
      },
    )
  end

  # @!endgroup

  private

  def scenarios
    SCENARIOS.map do |name, distance|
      {
        label: distance ? "#{name} (#{distance.inspect} left)" : name.to_s,
        name:,
        ends_at: distance&.from_now,
      }
    end
  end
end
