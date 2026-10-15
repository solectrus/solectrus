# How many days have a fresh summary, with a button that resets them all. On
# a phone a group of its own, as the groups of the settings form above it.
# The reset replaces the frame (see SummariesController#reset).
class Summary::Status::Component < ViewComponent::Base
  # completion_rate is the percent of the days with a fresh summary, or nil
  # without any summary
  def initialize(completion_rate:)
    super()
    @completion_rate = completion_rate
  end

  attr_reader :completion_rate
end
