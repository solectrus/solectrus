class Status::Component < ViewComponent::Base
  def initialize(live:, time:)
    super
    @live = live
    @time = time
  end
  attr_reader :live, :time
end
