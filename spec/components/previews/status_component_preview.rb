# @label Status
class StatusComponentPreview < ViewComponent::Preview
  # @!group Misc

  def without_state
    render Status::Component.new(time: 3.seconds.ago)
  end

  def with_state
    render Status::Component.new(
             time: 3.seconds.ago,
             system_status: 'BATTERY FULL',
           )
  end

  def with_state_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             system_status: 'PV + DISCHARGE',
             system_status_ok: true,
           )
  end

  def with_state_not_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             system_status: 'NPU-ERROR',
             system_status_ok: false,
           )
  end

  def fail_with_time
    render Status::Component.new(time: 30.seconds.ago)
  end

  def fail_without_time
    render Status::Component.new(time: nil)
  end

  # @!endgroup
end
