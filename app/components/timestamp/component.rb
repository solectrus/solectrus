class Timestamp::Component < ViewComponent::Base
  def initialize(timestamp:, timeframe:)
    super
    @timestamp = timestamp
    @timeframe = timeframe
  end
  attr_reader :timestamp, :timeframe

  def can_paginate?
    timeframe.in?(%w[day week month year])
  end

  def previous_timestamp
    result =
      case timeframe
      when 'day'
        timestamp - 1.day
      when 'week'
        timestamp - 1.week
      when 'month'
        timestamp - 1.month
      when 'year'
        timestamp - 1.year
      end

    helpers.out_of_range?(result) ? nil : result
  end

  def next_timestamp
    result =
      case timeframe
      when 'day'
        timestamp + 1.day
      when 'week'
        timestamp + 1.week
      when 'month'
        timestamp + 1.month
      when 'year'
        timestamp + 1.year
      end

    helpers.out_of_range?(result) ? nil : result
  end
end
