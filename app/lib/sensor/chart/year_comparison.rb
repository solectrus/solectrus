# Compares the same part of the year across the years: the parts of a year on
# the x axis, one dataset per year. The regular chart of the `all` timeframe
# puts the years themselves on a time axis, one bar each. That says how the
# years developed, but not whether this May beat the last one.
#
# How the year is cut is left to the subclasses: ByMonth draws twelve bars per
# year, ByQuarter and BySeason four. This class holds everything else.
#
# The chart draws the value of ONE sensor, never the composition its regular
# chart may draw (the inverters of a multi-inverter installation, the split of
# a battery charge): "one dataset per year" and "one dataset per sensor" cannot
# both hold, so the sensor keeps its own scalar value. Sensors that have none
# are excluded, see .available_for?. A pair of opposite bars is the exception,
# see OppositePair.
class Sensor::Chart::YearComparison < Sensor::Chart::Base
  include OppositePair

  # The comparisons there are. Each one carries the spelling the URL says as a
  # segment of its own (".../all/by_month"), so the route, the parameter check
  # and everything that builds such a path read it here -- as `Timeframe::REGEX`
  # owns the spelling of a timeframe.
  def self.variants
    [ByMonth, ByQuarter, BySeason]
  end

  # The comparison this spelling names, or nil if it names none.
  def self.for(param)
    variants.find { |variant| param == variant::PARAM }
  end

  # The spellings a route may carry. No anchors: a routing requirement must
  # not carry them.
  def self.regex
    /#{Regexp.union(variants.map { |variant| variant::PARAM })}/
  end

  # Opacity of the oldest year. The newest year is drawn in the full sensor
  # color and every older one a step paler, down to this floor. That keeps the
  # years apart without giving the sensor a second color.
  MIN_OPACITY = 0.45
  private_constant :MIN_OPACITY

  # A sensor this chart can draw. A `chart_only` sensor composes its chart from
  # others and reads null in every timeframe (see Sensor::Definitions::Dsl),
  # so there is nothing of its own to compare.
  # `nil?`, not `present?`: a chart answers `blank?` by loading its data, so
  # asking whether one exists must not read whether it has anything to show.
  # A sensor that has not measured yet still offers the comparison.
  def self.available_for?(sensor)
    return false if sensor.nil?

    !sensor.chart_only? && !sensor.chart(Timeframe.all).nil?
  end

  def initialize(timeframe:, sensor_name:)
    @sensor_name = sensor_name
    super(timeframe:)
  end

  attr_reader :sensor_name

  def type
    'bar'
  end

  # The gate of the regular chart holds here as well: the finance charts sit
  # behind :finance_charts (Sensor::Chart::FinanceBase), and a chart that only
  # rearranges their bars shows the same numbers.
  def permitted_feature_name
    regular_chart&.permitted_feature_name
  end

  # The color of a chart is the one its own chart picked -- autarky draws in
  # bg-sensor-autarky rather than in the background color of the sensor.
  def color_class(sensor)
    return super if regular_chart.nil?

    regular_chart.color_class(sensor)
  end

  # One bar, one tooltip. The other charts read a whole index at once, because
  # a point of a line says little without the points beside it. Here every bar
  # is a period of a year and stands on its own, and naming the one bar under
  # the cursor is also what lets a click drill down into exactly that period.
  def options
    super.deep_merge(
      interaction: {
        intersect: true,
        mode: 'nearest',
      },
      plugins: {
        tooltip: {
          # The bars of a period differ a lot in height, so a tooltip fixed to
          # the middle of the plot would often stand far from the bar it reads.
          # It follows the height of the bar instead.
          anchorToValues: true,
        },
      },
    )
  end

  private

  # What a subclass says about the way it cuts the year:
  #
  #   period                    the part of the year one bar stands for, as
  #                             the summaries group by it
  #   period_labels             the names of the parts, in the order of a year
  #   index_for(date)           which of those names a date falls under,
  #                             counted from zero
  #   drilldown_timeframe(date) the timeframe a click leads to
  #   tooltip_title(date)       the title of the tooltip, period and year
  #
  # Each of them is given the first day of the period, which is what the query
  # groups by, and which is also the year the period counts into.

  def regular_chart
    return @regular_chart if defined?(@regular_chart)

    @regular_chart = Sensor::Registry[sensor_name].chart(timeframe)
  end

  # One row per period instead of one per year.
  def sql_grouping_period
    period
  end

  # The regular chart of `all` sums every bucket, because it draws one bar per
  # year and nobody asks for the sum of a year of percentages. A bucket here is
  # shorter than a year, so the rule of the shorter timeframes applies instead:
  # energy adds up, a ratio and a temperature average.
  def preferred_meta_aggregation(sensor_def) = aggregation_by_unit(sensor_def)

  def build_data
    return unless series

    # Sorted, so that the opacity of a year follows its age.
    years = chart_sensor_names.flat_map { points_for(it).map { it.first.year } }.uniq.sort
    return if years.empty?

    {
      labels: period_labels,
      datasets: years.each_with_index.flat_map { |year, index| datasets_of(year, opacity_for(index, years.size)) },
      overlapping: false,
    }
  end

  # One dataset per sensor that measured something in the year.
  def datasets_of(year, opacity)
    chart_sensor_names.filter_map do |name|
      year_points = points_for(name).select { |date, _| date.year == year }
      dataset_for(name, year, year_points, opacity) if year_points.any?
    end
  end

  def points_for(name)
    (@points ||= {})[name] ||= build_points(name)
  end

  # [[date, value], ...] in date order, one entry per period that measured
  # something. The query fills every period of the range, up from the
  # installation date, so a year that measured nothing arrives as nothing but
  # nulls. Dropping them keeps that year out of the chart instead of drawing it
  # as a row of empty places.
  def build_points(name)
    sorted = sorted_points_for(name)
    values = transform_data(sorted.map(&:second), name)

    sorted.map(&:first).zip(values).select { |_date, value| value }
  end

  def dataset_for(name, year, points, opacity)
    sensor = Sensor::Registry[name]
    data = points.map { |date, value| data_point(date, value) }

    # The style drops its `colorScale`: a per-value color scale would overrule
    # the shade that tells the years apart, and both mean the same axis.
    dataset =
      style_for_sensor(sensor).except(:colorScale).merge(
        id: "#{name}-#{year}",
        label: dataset_label(sensor, year),
        data:,
        # Every year is a stack of its own: the bars of one year share a place
        # per period, the years stand side by side. The client reads the
        # height of a single bar off the data as well, and without this it
        # would add the years of one period up into an axis that is five times
        # too tall.
        stack: year.to_s,
        opacity:,
      )

    dataset[:hatchPartial] = true if data.any? { it[:partial] }
    dataset[:tooltipPrefix] = false unless opposite_directions?
    dataset
  end

  # An object rather than a bare number, so a click can carry the period it was
  # aimed at and the tooltip can name it. `x` names the category, which a bare
  # number could not -- and it is what lets a period without data leave the
  # list instead of standing in it as a null. Chart.js reads the FIRST element
  # to decide how it parses the whole dataset, so a leading null would make it
  # read every object as a number and draw nothing at all.
  def data_point(date, value)
    {
      x: period_labels[index_for(date)],
      y: value,
      # The axis has room for "Sep" or "Q3" only, and it names no year. The
      # tooltip speaks for one bar, so it names both and spells the period out.
      tooltipTitle: tooltip_title(date.to_date),
      drilldownPath: drilldown_path(date.to_date),
      partial: (true if partial?(date)),
    }.compact
  end

  # A period whose bar stands on fewer days than the period has is shorter for
  # a reason that has nothing to do with the periods it stands next to, so it
  # is drawn hatched to say so. Which periods those are is a property of the
  # timeframe, and it answers the same question for the MCP tools.
  def partial?(date)
    timeframe.partial_period?(date.to_date, period)
  end

  # Three months from `date`, as a range. No timeframe names a quarter or a
  # season, so a click on one leads to its days instead.
  def three_month_range(date)
    "#{date.iso8601}..#{(date + 2.months).end_of_month.iso8601}"
  end

  def drilldown_path(date)
    Rails.application.routes.url_helpers.public_send(
      drilldown_helper,
      sensor_name:,
      timeframe: drilldown_timeframe(date),
    )
  end

  # The page is the same for every point, and finding it reads the sensor list
  # of every page, so it is looked up once instead of once per bar drawn.
  def drilldown_helper
    @drilldown_helper ||=
      :"#{Sensor::HomePage.page_for(sensor_name)}_home_path"
  end

  # The newest year in the full sensor color, every older one a step paler.
  def opacity_for(index, count)
    return 1.0 if count < 2

    step = (1.0 - MIN_OPACITY) / (count - 1)
    ((step * index) + MIN_OPACITY).round(2)
  end

  # The index axis stacks, so the bars of one stack share a place: the pair of
  # a year, above and below the zero line. The value axis does not, so no bar
  # is lifted onto another.
  def x_scale_options
    {
      type: 'category',
      stacked: true,
      grid: {
        drawOnChartArea: false,
      },
      ticks: {
        maxRotation: 0,
        # The axis names the periods without a year, so the period we are in is
        # told apart by its weight rather than by its place.
        emphasize: index_for(Date.current),
      },
    }
  end

  def y_scale_options
    super.merge(stacked: false)
  end
end
