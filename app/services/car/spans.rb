# The span of a value of the driving card over the periods of the same kind:
# the lowest and the highest value of each day, week, month or year in the
# period of use of the cars, each with the period it comes from. The card
# places the value of its period in this span, so a month compares with the
# other months.
#
# Only a calendar period has periods of its kind. They end with the last day
# with data of the shown timeframe, like the day before yesterday for a guest
# (see Car::AdminOnlyDays). A period counts only when the cars were in use on
# each of its days up to then, because a car that
# started in the middle of a month gives a value of a few days. The shown
# period always counts, so its value lies in the span. A span needs
# MIN_PERIODS periods with a value, because fewer of them say nothing, and a
# lowest value below the highest.
#
# The spans read each day of the whole time, so the page asks for the
# summaries of the whole time first (see Car::Report.pending_days). The
# values of all periods are cached until a summary, a charging session or a
# car changes. The shown period only picks from them, so all periods of a
# kind share one entry.
class Car::Spans
  # The lowest and the highest value, and the timeframes they come from
  Span = Data.define(:min, :max, :min_timeframe, :max_timeframe)
  public_constant :Span

  # The format of a timeframe of each kind (see Timeframe)
  FORMATS = { day: '%F', week: '%G-W%V', month: '%Y-%m', year: '%Y' }.freeze
  private_constant :FORMATS

  MIN_PERIODS = 3
  private_constant :MIN_PERIODS

  # The kind of the timeframe, nil for a timeframe without spans
  def self.kind(timeframe) = FORMATS.keys.find { timeframe.public_send(:"#{it}?") }

  # The spans of the cars for the kind of the timeframe, nil for another
  # timeframe
  def self.for(timeframe, cars)
    kind = kind(timeframe)
    new(cars, kind, shown: timeframe.effective_beginning_date, max_date: timeframe.max_date) if kind
  end

  # `shown` is a date of the shown period, `max_date` the last day with data
  def initialize(cars, kind, shown:, max_date: Date.current)
    @cars = cars
    @kind = kind
    @shown = shown
    @max_date = max_date
  end

  # The span of the consumption (kWh per 100 km), nil without a span
  def consumption_per_100km = spans[:consumption_per_100km]

  # The span of the cost per 100 km, nil without a span
  def cost_per_100km = spans[:cost_per_100km]

  # The span of the average maximum range of one car, nil without a span
  def max_range = spans[:max_range]

  private

  attr_reader :cars, :kind

  # The cache holds numbers, strings and booleans only, so an entry of an
  # older version of the app reads without the classes of this one
  def spans
    @spans ||= Rails.cache.fetch(cache_key, expires_in: 1.day) { compute }.transform_values { span_of(it) if it }
  end

  def compute
    {
      consumption_per_100km: values { report.driving(it).consumption_per_100km },
      cost_per_100km: values { report.driving(it).cost_per_100km },
      max_range: (values { report.max_range(it) } if report.car),
    }
  end

  # The last day with data is part of the key, because the periods end there.
  # The shown period is not, because it only picks from the values.
  def cache_key
    ['car_span_values', cars.map(&:id), kind, @max_date, version(Car.where(id: cars)), version(Summary), version(ChargingSession)]
  end

  # The number of the rows and the time of the last update, in microseconds.
  # A deleted row changes no time of an update, so the number counts too.
  def version(scope)
    count, updated_at = scope.pick(Arel.sql('COUNT(*)'), Arel.sql('MAX(updated_at)'))
    "#{count}-#{updated_at&.to_fs(:usec)}"
  end

  # [[value, timeframe, in use throughout], ...] of each period with a value
  def values
    periods.filter_map do |dates|
      (value = yield dates) && [value, timeframe_string(dates.begin), in_use_throughout?(period_of(dates.begin))]
    end
  end

  # The span of the periods that count and of the shown one, nil without a
  # span
  def span_of(values)
    shown = timeframe_string(@shown)
    values = values.select { |_, timeframe, counts| counts || timeframe == shown }
    return if values.size < MIN_PERIODS

    (min, min_timeframe), (max, max_timeframe) = values.minmax_by(&:first)
    Span.new(min:, max:, min_timeframe: Timeframe.new(min_timeframe), max_timeframe: Timeframe.new(max_timeframe)) if min < max
  end

  # A report of the whole time reads the days of each period at once
  def report
    @report ||= Car::Report.new(Timeframe.new('all', max_date: @max_date), cars)
  end

  # The dates of each period of the kind in the whole time
  def periods
    @periods ||= report.dates.chunk { timeframe_string(it) }.map { |_, dates| dates.first..dates.last }
  end

  # The days of the period of the kind that holds the date. A day of a Date
  # would be a range of times.
  def period_of(date) = kind == :day ? date..date : date.public_send(:"all_#{kind}")

  # Whether the cars were in use on each day of the period up to the last day
  # with data
  def in_use_throughout?(period)
    period.begin >= in_use.begin && [period.end, @max_date].min <= in_use.end
  end

  # The days from the first day of use of a car to the last one, or to the
  # last day with data
  def in_use
    @in_use ||= cars.map(&:active_from).min..[cars.map { it.active_until || @max_date }.max, @max_date].min
  end

  # The timeframe of the period that holds the date
  def timeframe_string(date) = date.strftime(FORMATS[kind])
end
