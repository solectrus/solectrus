# @label Status
# @logical_path feedback
class StatusComponentPreview < ViewComponent::Preview
  # @!group Overview

  def without_state
    render Status::Component.new(time: 3.seconds.ago, max_age: 10.seconds)
  end

  def with_state
    render Status::Component.new(time: 3.seconds.ago, max_age: 10.seconds, status: 'BATTERY FULL')
  end

  def with_state_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             max_age: 10.seconds,
             status: 'PV + DISCHARGE',
             status_ok: true,
           )
  end

  def not_state_ok
    render Status::Component.new(
             time: 3.seconds.ago,
             max_age: 10.seconds,
             status: 'NPU-ERROR',
             status_ok: false,
           )
  end

  def fail_with_time
    render Status::Component.new(time: 30.seconds.ago, max_age: 10.seconds, status_ok: false)
  end

  def fail_without_time
    render Status::Component.new(time: nil, max_age: 10.seconds, status_ok: false)
  end

  # @!endgroup
end
