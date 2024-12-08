# @label Status
class StatusComponentPreview < ViewComponent::Preview
  # @!group Misc

  def without_state
    render Status::Component.new(time: 3.seconds.ago)
  end

  def with_state
    render Status::Component.new(time: 3.seconds.ago, status: 'BATTERY FULL')
  end

  def with_state_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             status: 'PV + DISCHARGE',
             status_ok: true,
           )
  end

  def with_state_not_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             status: 'NPU-ERROR',
             status_ok: false,
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
