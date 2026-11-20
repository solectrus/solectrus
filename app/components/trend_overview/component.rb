# The trends of a page as a grouped list (TrendOverview): per row the name
# of the sensor, its trend, and a chevron that leads to the insights of the
# sensor. The trend of a month or a year is its change
# (TrendOverview::Change::Component), the trend of the whole time are its
# years (TrendOverview::YearBars::Component).
class TrendOverview::Component < ViewComponent::Base
  def initialize(overview:)
    super()
    @overview = overview
  end

  attr_reader :overview

  delegate :groups, to: :overview

  # The groups, each with its lists of rows. A single group needs no
  # heading.
  def sections
    joined = joined_groups
    joined = [[nil, joined.first.last]] if joined.one?

    joined.map { |group, rows| [group, lists(rows)] }
  end

  def label(row) = TrendOverview.label(row.sensor, page: overview.page)

  # The insights of the sensor, which keep the parameters of the overview,
  # like its earlier period
  def href(row)
    helpers.insights_path(sensor_name: row.sensor.name, timeframe: overview.timeframe, **overview.link_params)
  end

  def trend(row)
    row.is_a?(TrendOverview::Years::Row) ? TrendOverview::YearBars::Component.new(row:) : TrendOverview::Change::Component.new(row:)
  end

  private

  # Groups of one row each in a row, like the electricity, the heat and the
  # costs of the heat pump, read as one group without a heading
  def joined_groups
    groups.chunk_while { |(_, rows), (_, next_rows)| rows.one? && next_rows.one? }.map do |run|
      run.one? ? run.first : [nil, run.flat_map(&:last)]
    end
  end

  # A total at the top, like the house consumption, stands apart from the
  # rows it sums up
  def lists(rows)
    total, *rest = rows
    TrendOverview.total?(total.sensor) && rest.any? ? [[total], rest] : [rows]
  end
end
