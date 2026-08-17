class ActionRequired::Component < ViewComponent::Base
  def initialize(registration_status:)
    super()
    @registration_status = registration_status.to_s.inquiry
  end

  attr_reader :registration_status

  delegate :unknown?, to: :registration_status, allow_nil: true

  # A missing registration outranks a missing sponsorship: without it the app
  # stops working, so it is the more urgent of the two.
  #
  # This icon says that a sponsorship is missing. It does not say that one
  # feature is locked, so it must not read `premium.sponsors_only`: that text
  # answers "why is this control disabled" next to the control itself.
  #
  # Every user sees this, admin or not. A user who cannot act on it can still
  # tell the person who can.
  # A visitor without the admin session cannot register, so the click leads to
  # the login instead. The text names that step, because the page behind it
  # speaks about the sponsoring and would otherwise answer a question this icon
  # did not ask.
  def tooltip
    return t('.prompt') if registration_status.complete?
    return t(".#{registration_status}") if helpers.admin?

    "#{t(".#{registration_status}")} – #{t('.login_required')}"
  end

  # The target follows the message of the tooltip, so the click leads where the
  # text points. A missing registration leads to the registration, a missing
  # sponsorship to the sponsoring page.
  #
  # An unused free month does not change this. The sponsoring page offers it
  # with its own button, which keeps this icon on one message.
  #
  # Only an admin can register the installation, and the registration page
  # turns everyone else away. Such a visitor goes to the sponsoring page: it
  # explains the situation and carries the login button, which is the one step
  # that is missing for them. That also keeps one target for every visitor who
  # cannot act, here and in the sidebar box.
  def path
    return helpers.sponsoring_path if registration_status.complete?
    return helpers.registration_path if helpers.admin?

    helpers.sponsoring_path
  end
end
