# Shows why this installation has the premium features - or why it has not.
# The reason itself comes from the PremiumStatus policy, this only renders it.
#
# Only this one question belongs here. The missing registration has its own
# banner above the page, so repeating it in the sidebar only made the panel
# loud without telling the user anything new.
#
# Every scenario carries its own keys in the locale file: title, description,
# icon, and where they apply countdown, cta_text and cta_link. The layout is
# the same for all of them and renders whatever is set, so a text change needs
# no Ruby.
#
# There is always a box at the bottom edge of the sidebar. Its color carries
# the state at a glance: green is fine, amber asks for something, gray is the
# local development mode.
class PremiumStatus::Component < ViewComponent::Base
  # Every grant this app can name. The update server can report one that is not
  # here, because a later release of the server can add a grant. Such a grant
  # opens the features all the same (see PremiumStatus), and the box then names
  # the feature set instead of the grant.
  KNOWN_REASONS = %i[
    sponsoring
    eligible_for_free
    free_trial
    intro
    development
  ].freeze
  public_constant :KNOWN_REASONS

  TONES = {
    sponsoring: :positive,
    eligible_for_free: :positive,
    intro: :positive,
    free_trial: :positive,
    granted: :positive,
    development: :neutral,
    locked_with_trial: :attention,
    locked: :attention,
    offline: :neutral,
  }.freeze
  private_constant :TONES

  BOXES = {
    positive:
      'bg-emerald-100 text-emerald-900 dark:bg-emerald-900 dark:text-gray-300',
    attention: 'bg-amber-100 text-amber-900 dark:bg-pink-800 dark:text-pink-100',
    neutral: 'bg-gray-100 text-gray-600 dark:bg-slate-700 dark:text-gray-300',
  }.freeze
  private_constant :BOXES

  # A locale file must not name any route it likes, so cta_link picks from
  # here. The free trial is started on the registration site, not in the app.
  LINKS = {
    'registration' => :registration_path,
    'sponsoring' => :sponsoring_path,
  }.freeze
  private_constant :LINKS

  def title
    value(:title)
  end

  def description
    value(:description)
  end

  def icon
    value(:icon)
  end

  # Only a phase that ends has a countdown, and only its locale entry carries
  # the plural forms.
  def countdown
    return @countdown if defined?(@countdown)

    @countdown = build_countdown
  end

  def cta_text
    value(:cta_text)
  end

  def cta_link
    helper = LINKS[value(:cta_link)]
    helpers.public_send(helper) if helper
  end

  def box_class
    BOXES[TONES[scenario]]
  end

  private

  def build_countdown
    ends_at = ::PremiumStatus.ends_at
    return unless ends_at

    days_left = (ends_at.to_date - Date.current).to_i.clamp(0..)
    t("#{scope}.countdown", count: days_left, default: nil).presence
  end

  # Every reason this app knows is a scenario of its own. A reason it does not
  # know keeps the box positive and says what the user has, because that part
  # is true whatever the grant is called. Only the locked state splits, because
  # the free month is offered just once.
  def scenario
    @scenario ||= granted_scenario || locked_scenario
  end

  def granted_scenario
    reason = ::PremiumStatus.reason
    return unless reason

    KNOWN_REASONS.include?(reason) ? reason : :granted
  end

  # Nothing is granted. That has two causes, and they must not read alike: the
  # update server answered "no", or it did not answer at all. Only the first
  # one is about the installation, and only the first one can be acted on.
  def locked_scenario
    return :offline if ::PremiumStatus.unknown?

    trial_offer? ? :locked_with_trial : :locked
  end

  # The free month starts on the registration page, which turns away every
  # visitor without the admin session. Such a visitor gets no button for it,
  # because it is one they cannot follow.
  def trial_offer?
    return @trial_offer if defined?(@trial_offer)

    @trial_offer = helpers.admin? && ::PremiumStatus.trial_available?
  end

  def scope
    @scope ||= ".#{scenario}"
  end

  # The template reads every key twice: once to decide whether to render the
  # block, once for the text itself. Asking I18n twice for that is waste.
  def value(key)
    values.fetch(key) do
      values[key] = t("#{scope}.#{key}", default: nil).presence
    end
  end

  def values
    @values ||= {}
  end
end
