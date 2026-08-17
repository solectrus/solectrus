# The banner that asks for the missing registration.
#
# It is rendered only while `ApplicationHelper#banner?` is true, and that asks
# for a missing registration. So `registration_status` is always `unregistered`
# or `pending` here. The template has no case for any other one, and would show
# an empty bar with a button.
class Banner::Component < ViewComponent::Base
  def initialize(registration_status:, admin:)
    super()

    @registration_status = registration_status.to_s.inquiry
    @admin = admin
  end

  attr_reader :registration_status, :admin

  delegate :pending?, :unregistered?, to: :registration_status
end
