# @label Status
class StatusComponentPreview < ViewComponent::Preview
  # @!group Misc

  def live
    render Status::Component.new(time: 3.seconds.ago)
  end

  def with_state
    render Status::Component.new(time: 3.seconds.ago, current_state: 'RUNNING')
  end

  def fail_with_time
    render Status::Component.new(time: 30.seconds.ago)
  end

  def fail_without_time
    render Status::Component.new(time: nil)
  end

  # @!endgroup
end
