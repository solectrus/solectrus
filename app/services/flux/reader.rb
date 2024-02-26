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
    now: '20s',
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
          Rails.application.config.x.influx.sensors.measurement(sensor),
          Rails.application.config.x.influx.sensors.field(sensor),
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

    start = start&.iso8601
    stop = stop&.iso8601

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

  # Cache expires depends on the timeframe
  DEFAULT_CACHE_EXPIRES = {
    day: 1.minute,
    week: 5.minutes,
    month: 10.minutes,
    year: 1.hour,
    all: 1.day,
  }.freeze
  private_constant :DEFAULT_CACHE_EXPIRES

  # Default cache options, can be overridden in subclasses
  def default_cache_options
    return unless timeframe

    { expires_in: DEFAULT_CACHE_EXPIRES[timeframe.id] }
  end
end
