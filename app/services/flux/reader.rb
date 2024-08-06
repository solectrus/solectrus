class Flux::Reader < Flux::Base
  def initialize(sensors:)
    super()

    @sensors = sensors
    @cache_options = default_cache_options
  end

  def call(timeframe)
    @timeframe = timeframe
  end

  attr_reader :fields, :measurements, :sensors, :timeframe

  private

  WINDOW = {
    now: '30s',
    day: '5m',
    week: '1d',
    month: '1d',
    year: '1mo',
    all: '1y',
  }.freeze
  private_constant :WINDOW

  def from_bucket
    "from(bucket: \"#{influx_bucket}\")"
  end

  def filter(selected_sensors: sensors)
    raw =
      selected_sensors.filter_map do |sensor|
        [
          SensorConfig.x.measurement(sensor),
          SensorConfig.x.field(sensor),
        ].compact.presence
      end

    # Build hash: Key is measurement, value is array of fields
    hash = raw.group_by(&:first).transform_values { |v| v.map(&:last) }

    # Build filter string
    filter =
      hash.map do |measurement, fields|
        field_filter =
          fields.map { |field| "r[\"_field\"] == \"#{field}\"" }.join(' or ')

        "r[\"_measurement\"] == \"#{measurement}\" and (#{field_filter})"
      end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def range(start:, stop: nil)
    @cache_options = cache_options(stop:)

    start = start&.rfc3339(9)
    stop = stop&.rfc3339(9)

    stop ? "range(start: #{start}, stop: #{stop})" : "range(start: #{start})"
  end

  def location
    "timezone.location(name: \"#{Rails.application.config.time_zone}\")"
  end

  def query(string)
    if @cache_options
      Rails
        .cache
        .fetch(cache_key(string), @cache_options) do
          query_without_cache(string)
        end
    else
      query_without_cache(string)
    end
  end

  def query_with_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = end_time - start_time

    [result, duration]
  end

  def query_without_cache(string)
    result, duration =
      query_with_time { client.create_query_api.query(query: string) }

    ActiveSupport::Notifications.instrument(
      'query.flux_reader',
      class: self.class.name,
      query: string,
      sensors:,
      duration:,
    )

    result
  end

  # Build a short cache key from the query string to avoid hitting the 250 chars
  def cache_key(string)
    Digest::SHA2.hexdigest("flux/v2/#{string}")
  end

  def cache_options(stop:)
    # Cache forever if the result cannot change anymore
    return {} if stop&.past?

    default_cache_options
  end

  # Default cache options, can be overridden in subclasses
  def default_cache_options
    return if timeframe.nil? || timeframe.now?

    # The cache expiry should depend on how long the observed timeframe is.
    #
    # The result of a query that summarises half of the year is unlikely to
    # change a few minutes later, so we can cache it for a longer time.
    #
    # But the result of a query that only summarises the past hours of
    # today can change considerably in just a few minutes.
    #
    # So we use a sliding scale of cache expiry times:
    # For each day in the timeframe, we add 2 minutes to the cache expiry time.
    # Minimum cache expiry time is 1 minute
    #
    { expires_in: ((timeframe.days_passed * 2) + 1).minutes }
  end
end
