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
    return 0 if percent?

    trend.sensor.trend_aggregation == :avg ? 1 : 0
  end

  def percent?
    trend.sensor.unit == :percent
  end

  def show_diff_value?
    percent? || trend.sensor.trend_aggregation == :avg
  end

  def show_absolute_values?
    show_diff_value? && !percent?
  end

  def diff_suffix
    if percent?
      " #{t('.percentage_points')}"
    elsif show_absolute_values?
      ''
    else
      '%'
    end
  end

  def formatted_value(value)
    Sensor::ValueFormatter.new(
      value,
      unit: trend.sensor.unit,
      context: :total,
      scaling: :kilo,
      precision: diff_precision,
    ).to_s
  end
end
