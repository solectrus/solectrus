# Who may see the amortization page, and in what shape.
#
# The admin sets one three-state visibility ('all', 'admins' or 'none'), stored
# in two booleans. That encoding lives here and nowhere else - .level reads it,
# .level= writes it, and every question below is asked of .level rather than of
# the settings.
#
# Deliberately not part of its neighbour ApplicationPolicy: that one is the
# singleton answering which sponsor features this installation has, and this
# class asks it for exactly that one fact (.licensed?).
class AmortizationVisibility
  # In the order the settings form offers them.
  LEVELS = %w[all admins none].freeze
  public_constant :LEVELS

  def self.level
    return 'none' unless Setting.enable_amortization

    Setting.amortization_public ? 'all' : 'admins'
  end

  # Exposing the calculation to non-admins is a sponsor feature, so 'all' falls
  # back to admins-only without it.
  def self.level=(level)
    case level
    when 'all'
      Setting.enable_amortization = true
      Setting.amortization_public = licensed?
    when 'admins'
      Setting.enable_amortization = true
      Setting.amortization_public = false
    when 'none'
      Setting.enable_amortization = false
    else
      raise ArgumentError, "Unknown visibility level: #{level.inspect}"
    end
  end

  # Whether the page is there at all. Disabling it entirely removes the
  # navigation entry; a direct request must then 404 like any unknown URL - for
  # everyone, admins included.
  def self.enabled? = level != 'none'

  # Whether the sponsor feature is active - the same answer for every viewer, so
  # it needs none.
  def self.licensed? = ApplicationPolicy.amortization?

  # The viewer's admin state is handed in rather than read from the session -
  # nothing below the controller should know where it comes from.
  def initialize(admin:)
    @admin = admin
  end

  delegate :level, :enabled?, :licensed?, to: :class

  # Whether the viewer is past the login barrier: the calculation is either
  # public or the viewer is an admin. Says nothing about the sponsor feature.
  def unlocked? = admin || level == 'all'

  # Why this viewer may not see the calculation, or nil when they may. The order
  # is deliberate: a viewer who is only missing the login is told so rather than
  # being sent to the sponsor teaser.
  def denial_reason
    return :restricted unless unlocked?
    return :unavailable unless licensed?

    nil
  end

  # Whether this viewer may see the calculation. Everyone else gets a hint, so
  # nothing is computed and no sub-navigation is shown.
  def visible? = denial_reason.nil?

  private

  attr_reader :admin
end
