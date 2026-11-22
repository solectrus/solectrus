class Trend
  BASES = %i[previous_year previous_period].freeze
  public_constant :BASES

  # The earlier period of a timeframe, which depends on no sensor: the year
  # before or, for a month, the month before. A year has no other earlier
  # period than the year before.
  def self.base_timeframe(timeframe, base)
    raise ArgumentError, "Invalid base: #{base}" unless base.in?(BASES)

    base == :previous_period && !timeframe.year_like? ? shift(timeframe, 1.month) : shift(timeframe, 1.year)
  end

  # The days of a period that compare with the earlier period. Today has
  # not ended, so a running period compares its days up to yesterday, and
  # the earlier period the same days. A visitor of the car page sees fewer
  # days already (see Car::AdminOnlyDays). A past period compares as a
  # whole, and the whole time has no earlier period.
  def self.compared_timeframe(timeframe)
    return timeframe if timeframe.all? || !timeframe.current?

    Timeframe.new("#{timeframe.effective_beginning_date}..#{[timeframe.effective_ending_date, Date.yesterday].min}")
  end

  # The same days one step earlier (see .compared_timeframe), a past month
  # or year as a whole. The days of a running month can shrink to a single
  # day the month before, like the 29th to the 30th of March to the 28th of
  # February.
  def self.shift(timeframe, step)
    raise ArgumentError, "timeframe unknown: #{timeframe}" unless timeframe.month_like? || timeframe.year_like?

    if timeframe.current?
      compared = compared_timeframe(timeframe)
      from = compared.effective_beginning_date - step
      to = compared.effective_ending_date - step
      Timeframe.new(from == to ? from.to_s : "#{from}..#{to}")
    else
      day = timeframe.date - step
      Timeframe.new(timeframe.year_like? ? day.year.to_s : day.strftime('%Y-%m'))
    end
  end
  private_class_method :shift

  # The value of a sensor in a period, aggregated like its trend (see
  # Sensor::Query::Helpers::Sql::DslBuilder#trend). Nil without a value.
  def self.value(sensor, timeframe)
    data = Sensor::Query::Total.new(timeframe) { it.trend(sensor.name) }.call
    data.public_send(sensor.name) if data.respond_to?(sensor.name)
  end

  # The weighted value of a sensor in a period of days (see
  # Sensor::Definitions::Dsl#trend), which a page shows beside the plain
  # average. A single day has no other days to weight, and a sensor
  # without a weighted trend has none.
  def self.weighted_value(sensor, timeframe)
    return unless sensor.trend_weighted?
    return if timeframe.now? || timeframe.hours? || timeframe.days_passed <= 1

    value(sensor, timeframe)
  end

  # Whether the earlier period has data from its first day on, so it
  # compares as a whole. The year of the installation begins before the
  # first day of data and has fewer days, also where the period itself
  # starts at the installation (Timeframe#effective_beginning_date).
  def self.complete?(base_timeframe, first_date:)
    first_date.present? && base_timeframe.beginning.to_date >= first_date
  end

  # The first day of the summaries of a sensor, nil without one. A sensor
  # without summaries of its own counts from the first of the sensors it is
  # calculated from. A weighted trend begins no earlier than its weight: a
  # day without it does not count (see Sensor::Definitions::Dsl#trend).
  # `first_dates` holds the first day of each field (see
  # TrendOverview#first_dates).
  def self.first_date(sensor, first_dates:)
    first = first_dates.values_at(*source_fields(sensor).map(&:to_s)).compact.min
    return first unless sensor.trend_weighted?

    weight_first = first_dates[sensor.trend_weight.to_s]
    [first, weight_first].max if first && weight_first
  end

  # The fields of the summaries that a sensor is calculated from, and the
  # field that weights its trend
  def self.summary_fields(sensor)
    fields = source_fields(sensor)
    sensor.trend_weighted? ? fields | [sensor.trend_weight] : fields
  end

  def self.source_fields(sensor)
    Sensor::DependencyResolver
      .new(sensor.name, context: :sql)
      .resolve
      .select { Sensor::Registry[it].store_in_summary? }
  end
  private_class_method :source_fields

  # `base_data` holds the values of the earlier period, which a caller
  # fetches once for all its sensors (see TrendOverview::Changes), and
  # `first_date` the first day of the sensor (Trend.first_date)
  def initialize(sensor:, timeframe:, current_value:, base:, base_data:, first_date:)
    raise ArgumentError, "Invalid base: #{base}" unless base.in?(BASES)

    @sensor = sensor
    @timeframe = timeframe
    @base = base
    @current_value = current_value
    @base_data = base_data
    @first_date = first_date
  end

  attr_reader :sensor, :timeframe, :base, :current_value, :first_date

  def valid?
    return @valid if defined?(@valid)

    # Don't show trends for single-day ranges - check this first to avoid
    # creating invalid base_timeframe ranges
    @valid = timeframe.days_passed > 1 && Trend.complete?(base_timeframe, first_date:)
  end

  def base_timeframe
    @base_timeframe ||= Trend.base_timeframe(timeframe, base)
  end

  def base_value
    return unless valid?
    return unless base_data.respond_to?(sensor.name)

    @base_value ||= base_data.public_send(sensor.name)
  end

  # A trend needs a base value, and a zero gives no ratio to compare with
  def comparable?
    base_value.present? && !base_value.zero?
  end

  # The change in percent of the base value. Its sign is the sign of the
  # difference, also for a negative base value, like savings below zero.
  def percent
    return unless comparable? && current_value

    diff.fdiv(base_value.abs) * 100
  end

  def diff
    return unless base_value && current_value

    current_value - base_value
  end

  private

  attr_reader :base_data
end
