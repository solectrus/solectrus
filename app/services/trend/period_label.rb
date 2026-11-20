# The earlier period of a trend, as short as it can be, so it fits beside a
# label on a phone: "Dec 2025" for a month, "1.-27. Aug 2026" with an en
# dash for a range of days up to yesterday
class Trend::PeriodLabel
  # A period as short as it can be, like the earlier one: "Nov 2026" for a
  # month, its name for any other period
  def self.short(timeframe)
    timeframe.month? ? I18n.l(timeframe.date, format: I18n.t('trend.period.month')) : timeframe.localized
  end

  def initialize(timeframe)
    @timeframe = timeframe
  end

  attr_reader :timeframe

  def to_s
    return self.class.short(timeframe) unless timeframe.range?

    from = timeframe.beginning.to_date
    to = timeframe.ending.to_date
    if from.year != to.year
      timeframe.localized
    elsif from.month == to.month
      "#{I18n.l(from, format: format(:from_same_month))}–#{I18n.l(to, format: format(:to_same_month))}"
    else
      "#{I18n.l(from, format: format(:from_same_year))} – #{I18n.l(to, format: format(:to))}"
    end
  end

  private

  def format(key) = I18n.t(key, scope: 'trend.period')
end
