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
# The box sits at the bottom edge of the sidebar. Its color carries the state
# at a glance: green is fine, amber asks for something, gray is the local
# development mode.
#
# It has two layouts. The wide one gives the description and the call to
# action a line of their own. The compact one runs all parts into a single
# line, separated by a middot. The menu on a phone asks for the compact one,
# because it shares its height with the page below it.
class PremiumStatus::Component < ViewComponent::Base
  # Every grant this app can name. The update server can report one that is not
  # here, because a later release of the server can add a grant. Such a grant
  # opens the features all the same (see PremiumStatus), and the box then names
  # the feature set instead of the grant.
  KNOWN_REASONS = %i[sponsoring free_trial intro development].freeze
  public_constant :KNOWN_REASONS

  # A grant the user did not ask for and cannot act on. The live demo is such
  # an installation. To name it in the sidebar only raises the question why
  # this installation is free, so the box stays away.
  SILENT_REASONS = %i[eligible_for_free].freeze
  public_constant :SILENT_REASONS

  TONES = {
    sponsoring: :positive,
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

  # scenario and ends_at name a state directly instead of reading it from the
  # policy. Only the Lookbook preview passes them, because it must show every
  # state on one page and an installation is in exactly one of them. The app
  # itself leaves both out and the policy decides.
  def initialize(compact: false, scenario: nil, ends_at: nil)
    super()
    @compact = compact
    @scenario = scenario
    @given_ends_at = ends_at
  end

  def render?
    return true if @scenario

    SILENT_REASONS.exclude?(PremiumStatus.reason)
  end

  def title
    value(:title)
  end

  # The compact layout has one line for the whole box, so a scenario can carry
  # a shorter text for it. Most of them do, because the long text needs two
  # lines or three on the screen of a phone. A scenario that is short enough
  # already names no second text, and both layouts then use the same one.
  #
  # A scenario with a call to action drops the description in the compact
  # layout. The two together are wider than the screen of a phone, and the
  # button already says what the user can do.
  def description
    return if @compact && cta_text

    @compact ? compact_description : value(:description)
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

  # The second part of the box. A scenario can carry a description, a call to
  # action, or both.
  def detail?
    description.present? || cta_text.present?
  end

  def box_layout
    @compact ? 'items-baseline gap-2 px-4 py-2' : 'items-start gap-3 p-4'
  end

  def icon_layout
    @compact ? nil : 'fa-lg mt-0.5'
  end

  # The compact layout is a single row. It sends the two parts to opposite
  # ends, which keeps the middle free and makes the row easy to scan. The wide
  # layout stacks them, so neither part is a flex item there.
  def body_layout
    'flex grow items-baseline justify-between gap-4' if @compact
  end

  # min-w-0 lets a long title wrap. With shrink-0 the row keeps the title on
  # one line and pushes it out of the box, which iOS Safari really does.
  def title_layout
    @compact ? 'min-w-0' : 'block'
  end

  # The compact layout needs the description and the call to action in one box,
  # because that box is what the row pushes to the right. min-w-0 lets its text
  # wrap instead of making the row wider than the whole box. The wide layout
  # wants no box around them at all, and "contents" removes it.
  def detail_layout
    @compact ? 'min-w-0 text-right' : 'contents'
  end

  def description_layout
    @compact ? 'inline' : 'block mt-1'
  end

  def cta_layout
    @compact ? 'inline' : 'block mt-2'
  end

  # Only the compact layout needs a mark between the two, because there it
  # follows the description in the same line.
  def cta_separator
    ' · ' if @compact && description
  end

  private

  # A scenario names compact_description when the long text needs a second line
  # on a phone. An empty one means the title says enough on its own, and the
  # row then carries no second text. A scenario without the key keeps the long
  # text for both layouts.
  def compact_description
    short = t("#{scope}.compact_description", default: nil)
    return value(:description) if short.nil?

    short.presence
  end

  def build_countdown
    ends_at = @given_ends_at || PremiumStatus.ends_at
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
    reason = PremiumStatus.reason
    return unless reason

    KNOWN_REASONS.include?(reason) ? reason : :granted
  end

  # Nothing is granted. That has two causes, and they must not read alike: the
  # update server answered "no", or it did not answer at all. Only the first
  # one is about the installation, and only the first one can be acted on.
  def locked_scenario
    return :offline if PremiumStatus.unknown?

    trial_offer? ? :locked_with_trial : :locked
  end

  # The free month starts on the registration page, which turns away every
  # visitor without the admin session. Such a visitor gets no button for it,
  # because it is one they cannot follow.
  def trial_offer?
    return @trial_offer if defined?(@trial_offer)

    @trial_offer = helpers.admin? && PremiumStatus.trial_available?
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
