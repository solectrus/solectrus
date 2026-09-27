class TrendIndicator::Component < ViewComponent::Base
  def initialize(trend:)
    super()
    @trend = trend
  end

  attr_reader :trend

  def icon_name
    if trend.diff.positive?
      'arrow-trend-up'
    elsif trend.diff.negative?
      'arrow-trend-down'
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

  def percent?
    trend.sensor.unit == :percent
  end

  def show_diff_value?
    percent? || avg?
  end

  def diff_suffix
    if percent?
      " #{t('.percentage_points')}"
    elsif avg?
      ''
    else
      '%'
    end
  end

  private

  def avg?
    trend.sensor.trend_aggregation == :avg
  end
end
