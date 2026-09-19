# Four quarters on the x axis, one dataset per year. A quarter holds three
# months, so a year of it reads as a season rather than as a month: how the
# winters compare, or how much more the summer of this year made.
class Sensor::Chart::YearComparison::ByQuarter < Sensor::Chart::YearComparison
  PARAM = 'by_quarter'.freeze
  public_constant :PARAM

  # The menu entry that leads here.
  LABEL_KEY = 'data.quarters_across_years'.freeze
  public_constant :LABEL_KEY

  # The axis says "Q1" in every language this app speaks, so the labels are
  # not translated. The tooltip has the room to spell the quarter out, and
  # does (see data.quarter_with_year).
  LABELS = %w[Q1 Q2 Q3 Q4].freeze
  private_constant :LABELS

  private

  def period
    :quarter
  end

  def period_labels
    LABELS
  end

  def index_for(date)
    date.quarter - 1
  end

  def drilldown_timeframe(date)
    three_month_range(date)
  end

  def tooltip_title(date)
    I18n.t('data.quarter_with_year', quarter: date.quarter, year: date.year)
  end
end
