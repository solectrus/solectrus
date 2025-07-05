class TrendIndicator::Component < ViewComponent::Base
  def initialize(trend:)
    super
    @trend = trend
  end

  attr_reader :trend

  def icon
    if trend.diff.positive?
      'fa-arrow-trend-up'
    elsif trend.diff.negative?
      'fa-arrow-trend-down'
    end
  end

  def color_class
    if (trend.diff.positive? && trend.more_is_better?) ||
         (trend.diff.negative? && !trend.more_is_better?)
      'text-green-600'
    else
      'text-red-700 dark:text-red-400'
    end
  end
end
