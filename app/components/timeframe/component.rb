class Timeframe::Component < ViewComponent::Base
  def initialize(timeframe:)
    super
    @timeframe = timeframe
  end
  attr_reader :timeframe

  def can_paginate?
    !timeframe.now? && !timeframe.all?
  end

  def options
    { controller: "swipe" }
  end
end
