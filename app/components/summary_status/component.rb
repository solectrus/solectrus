# How many days have a fresh summary, with a button that resets them all.
# The reset replaces the frame (see SummariesController#reset).
class SummaryStatus::Component < ViewComponent::Base
  # completion_rate is the percent of the days with a fresh summary, or nil
  # without any summary
  def initialize(completion_rate:)
    super()
    @completion_rate = completion_rate
  end

  attr_reader :completion_rate
end
