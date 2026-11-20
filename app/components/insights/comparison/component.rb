# The insights below the trend overview of a month or a year: what is
# behind the change that the overview shows (see Insights::Comparison).
# First the value of the period beside the value of the earlier one. A year
# then shows the change of each month as a bar, so the months that made
# the change stand out, and its calendar. The days come last: the average
# day then and now, and the lowest and the highest day with a link to it.
#
# `page_label` is the name of the page (TrendOverview.label), `base` the
# earlier period (Trend::BASES), `controller_namespace` the home page that
# a day leads to.
class Insights::Comparison::Component < ViewComponent::Base
  def initialize(comparison:, page_label:, base:, controller_namespace:)
    super()
    @comparison = comparison
    @page_label = page_label
    @base = base
    @controller_namespace = controller_namespace
  end

  attr_reader :comparison, :page_label

  delegate :total, :months, :days, :extremes, :heatmap_data, :heatmap_tile, :sensor, :timeframe, :base_timeframe, to: :comparison

  def base_period = Trend::PeriodLabel.new(base_timeframe).to_s

  # A period that still runs reads like the earlier one, from its first day
  # to yesterday, so both rows name the days they compare
  def current_period
    return Trend::PeriodLabel.short(timeframe) if comparison.current_timeframe.equal?(timeframe)

    Trend::PeriodLabel.new(comparison.current_timeframe).to_s
  end

  # The earlier value of a figure of the days, below its label, like
  # "Previous year: 10.7 kWh". The whole time has none.
  def base_detail(row)
    return unless base_timeframe

    "#{t("trends.index.#{@base}")}: #{text(row, row.base)}"
  end

  def label(row) = t(".#{row.key}")

  def month_label(row) = l(row.key, format: '%b')

  def text(row, value) = value.nil? ? '–' : format(row, value)

  # The change below a value, like "+326 kWh". None without both values,
  # and none where both read the same, even where they differ a little.
  # It is the change of the values as they read, so 10.7 to 10.8 kWh
  # reads "+0.1 kWh", not "+0 kWh".
  def value_change(row) = (format(row, shown_diff(row), sign: true) if row.diff && !same?(row))

  # The change of a month, a dash without both values. All months read in
  # the unit and with the decimals of the largest change, so they line up,
  # and a zero with its unit where the change rounds to zero.
  def month_change(row)
    return '–' unless row.diff
    return "±#{month_format(row, 0)}" if same_month?(row)

    month_format(row, row.unit.in?(%i[percent days]) ? shown_diff(row) : row.diff)
  end

  # The month and its value, then and now, for the tooltip of a month
  def month_values(row)
    [[row.key, row.current], [row.key.prev_year, row.base]].map do |month, value|
      "#{l(month, format: '%b %Y')}: #{text(row, value)}"
    end
  end

  # Green for better, red for worse, gray for neither
  def change_class(row) = TrendOverview::Change::Component::RATING_CLASSES[same?(row) ? :same : row.rating]

  # The same for a month, as its change reads (see #same_month?)
  def month_class(row) = TrendOverview::Change::Component::RATING_CLASSES[month_rating(row)]

  # The bar of a month on the scale of the largest change of all months.
  # The tooltip of the month points to its zero.
  def bar(row)
    TrendOverview::Bar::Component.new(change: row.diff, rating: month_rating(row), scale: months_scale, data: { 'tooltip-target' => 'anchor' })
  end

  # The page of the sensor on a day. Its link leaves the sheet for the
  # page. The car page keeps the selected car.
  def day_path(day)
    if sensor.is_a?(Sensor::Definitions::CarPageChart)
      helpers.cars_home_path(sensor_name: nil, timeframe: day.to_s, car: comparison.car_param)
    else
      page_path(day.to_s)
    end
  end

  # The longest streak of a charged battery leads to its days on the page
  def row_path(row)
    return unless row.key == :charged_consecutively

    from, to, = comparison.streak.values
    page_path("#{from}..#{to}") if from && to && to > from
  end

  private

  def page_path(timeframe) = url_for(sensor_name: sensor.name, timeframe:, controller: "#{@controller_namespace}/home")

  def same?(row) = row.diff && (row.diff.zero? || text(row, row.base) == text(row, row.current))

  def shown_diff(row) = shown(row, row.current) - shown(row, row.base)

  # A value as the sheet shows it, rounded to its decimals (see #format)
  def shown(row, value)
    case row.unit
    when :days then value
    when :percent then value.round
    else
      formatter = Sensor::ValueFormatter.new(value, unit: row.unit, context: :total, scaling: :kilo)
      (value / formatter.divisor).round(formatter.precision) * formatter.divisor
    end
  end

  def month_rating(row) = same_month?(row) ? :same : row.rating

  # A month without a change, as its change reads in the unit and with the
  # decimals of all months, so a small change shows no "-0 kWh"
  def same_month?(row)
    return same?(row) if row.unit.in?(%i[percent days])

    row.diff && month_formatter(row, row.diff).then { (row.diff / it.divisor).round(months_precision).zero? }
  end

  def months_scale = @months_scale ||= months.filter_map { it.diff&.abs }.max.to_f

  # A percentage changes by points and a count of days in days, as for the
  # other figures. Any other unit takes the scale and the decimals of the
  # largest change, at least a kilo, like the values of the sheet.
  def month_format(row, value)
    return format(row, value, sign: true) if row.unit.in?(%i[percent days])

    month_formatter(row, value).to_s
  end

  def month_formatter(row, value)
    Sensor::ValueFormatter.new(value, unit: row.unit, context: :total, scaling: months_magnitude, precision: months_precision, sign: true)
  end

  def months_magnitude = [months_scale, 1_000].max

  def months_precision
    @months_precision ||= Sensor::ValueFormatter.new(months_scale, unit: sensor.unit, context: :total, scaling: months_magnitude).precision
  end

  def format(row, value, sign: false)
    case row.unit
    when :days
      "#{number(value, sign:)} #{t('.days', count: value.abs)}"
    when :percent
      sign ? "#{number(value, sign:)} #{t('trend.percentage_points')}" : Sensor::ValueFormatter.new(value, unit: :percent, precision: 0).to_s
    else
      Sensor::ValueFormatter.new(value, unit: row.unit, context: :total, scaling: :kilo, sign:).to_s
    end
  end

  def number(value, sign:) = Sensor::ValueFormatter.new(value, unit: :unitless, precision: 0, sign:).to_s
end
