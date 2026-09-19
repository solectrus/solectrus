# Twelve months on the x axis, one dataset per year: whether this May beat the
# last one.
class Sensor::Chart::YearComparison::ByMonth < Sensor::Chart::YearComparison
  PARAM = 'by_month'.freeze
  public_constant :PARAM

  # The menu entry that leads here.
  LABEL_KEY = 'data.months_across_years'.freeze
  public_constant :LABEL_KEY

  private

  def period
    :month
  end

  # Read once per point, so the lookup is kept rather than repeated.
  def period_labels
    @period_labels ||= I18n.t('date.abbr_month_names').drop(1)
  end

  def index_for(date)
    date.month - 1
  end

  def drilldown_timeframe(date)
    date.strftime('%Y-%m')
  end

  def tooltip_title(date)
    I18n.l(date, format: :month)
  end
end
