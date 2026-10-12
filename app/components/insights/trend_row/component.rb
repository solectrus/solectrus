# The comparison with an earlier period as a row: the trend as its value, the
# earlier period beside the label, and its value as the detail, so no tooltip
# must explain the trend. The row leads to the earlier period.
class Insights::TrendRow::Component < ViewComponent::Base
  def initialize(trend:, label:, url:)
    super()
    @trend = trend
    @label = label
    @url = url
  end

  attr_reader :trend, :label, :url

  def render?
    trend&.comparable?
  end

  # The period as short as it can be, so it fits beside the label on a
  # phone: "Dec 2025" for a month, "1.-27. Aug 2026" with an en dash for a
  # range of days up to today
  def period
    timeframe = trend.base_timeframe
    return l(timeframe.date, format: t('.month')) if timeframe.month?
    return timeframe.localized unless timeframe.range?

    from = timeframe.beginning.to_date
    to = timeframe.ending.to_date
    if from.year != to.year
      timeframe.localized
    elsif from.month == to.month
      "#{l(from, format: t('.from_same_month'))}–#{l(to, format: t('.to_same_month'))}"
    else
      "#{l(from, format: t('.from_same_year'))} – #{l(to, format: t('.to'))}"
    end
  end

  def base_value
    Sensor::ValueFormatter.new(
      trend.base_value,
      unit: trend.sensor.unit,
      context: :total,
      scaling: :kilo,
      precision: trend.precision,
    ).to_s
  end
end
