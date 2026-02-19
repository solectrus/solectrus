class TrendIndicator::Component < ViewComponent::Base
  def initialize(trend:)
    super()
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
      'text-signal-positive'
    else
      'text-signal-negative'
    end
  end

  def diff_precision
    trend.sensor.trend_aggregation == :avg ? 1 : 0
  end

  def show_absolute_values?
    trend.sensor.trend_aggregation == :avg
  end
end
