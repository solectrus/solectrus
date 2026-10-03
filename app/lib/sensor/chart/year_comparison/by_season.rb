# Four seasons on the x axis, one dataset per year. A quarter cuts the year
# where the calendar does, which puts deep winter and early spring into one
# bar. A season cuts it where the sun does, so the bars stand for what the
# yield of a photovoltaic system really follows.
#
# These are the meteorological seasons, the only ones that fall on whole
# months: winter is December, January and February. A winter therefore runs
# over the turn of the year, and it counts into the year it begins in. The
# bars of a year then run left to right in the order they ran in, as they do
# in the other comparisons, and the last bar of the year we are in is the
# newest one rather than a winter from nine months ago. The tooltip names both
# years of a winter, so no bar rests on that choice.
class Sensor::Chart::YearComparison::BySeason < Sensor::Chart::YearComparison
  PARAM = 'by_season'.freeze
  public_constant :PARAM

  # The menu entry that leads here.
  LABEL_KEY = 'data.seasons_across_years'.freeze
  public_constant :LABEL_KEY

  # The axis begins where the sun comes back rather than where the calendar
  # begins. A winter therefore stands at the right end of its year, although
  # it ran before the spring beside it.
  SEASONS = %w[spring summer autumn winter].freeze
  private_constant :SEASONS

  private

  def period
    :season
  end

  def period_labels
    @period_labels ||= SEASONS.map { I18n.t("data.seasons.#{it}") }
  end

  # A month ahead of a date lies the quarter that holds its whole season:
  # December reads as January and joins the two months that follow it. That
  # holds for the first day of a season as much as for any other date, so the
  # axis can ask this about today as well.
  def index_for(date)
    # The quarters run winter, spring, summer, autumn, the axis runs spring,
    # summer, autumn, winter. Two places on, wrapped around.
    ((date + 1.month).quarter + 2) % 4
  end

  def drilldown_timeframe(date)
    three_month_range(date)
  end

  # A winter runs over the turn of the year, so one year would leave its bar
  # ambiguous. It names both.
  def tooltip_title(date)
    index = index_for(date)
    season = period_labels[index]
    return I18n.t('data.season_with_year', season:, year: date.year) unless
      SEASONS[index] == 'winter'

    I18n.t(
      'data.season_with_years',
      season:,
      from: date.year,
      to: format('%02d', (date.year + 1) % 100),
    )
  end
end
