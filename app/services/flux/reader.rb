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

  WINDOW = { now: '30s', day: '5m' }.freeze
  private_constant :WINDOW

  def from_bucket
    "from(bucket: \"#{influx_bucket}\")"
  end

  def filter(selected_sensors: sensors)
    # Group sensors by their measurement
    grouped =
      selected_sensors.each_with_object(
        Hash.new { |h, k| h[k] = [] },
      ) do |sensor, result|
        measurement = SensorConfig.x.measurement(sensor)
        field = SensorConfig.x.field(sensor)
        result[measurement] << field if measurement && field
      end

    # Generate filter conditions
    filter_conditions =
      grouped.map do |measurement, fields|
        field_conditions =
          fields.map { |field| "r[\"_field\"] == \"#{field}\"" }.join(' or ')

        "r[\"_measurement\"] == \"#{measurement}\" and (#{field_conditions})"
      end

    # Combine all conditions into the final filter string
    "filter(fn: (r) => #{filter_conditions.join(' or ')})"
  end

  def range(start:, stop: nil)
    @cache_options = cache_options(stop:)

    start = start&.iso8601
    stop = stop&.iso8601

    stop ? "range(start: #{start}, stop: #{stop})" : "range(start: #{start})"
  end

  def query(string)
    if @cache_options
      Rails
        .cache
        .fetch(cache_key(string), **@cache_options) do
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

  def empty_hash
    sensors.index_with(nil).merge(time: nil)
  end

  # Build a short cache key from the query string to avoid hitting the 250 chars
  def cache_key(string)
    "flux:#{Digest::SHA256.hexdigest(string)}"
  end

  def cache_options(stop:)
    # Cache forever if the result cannot change anymore
    return {} if stop&.past?

    default_cache_options
  end

  # Default cache options, can be overridden in subclasses
  def default_cache_options
    return if timeframe.nil? || timeframe.now?

    { expires_in: 3.minutes }
  end
end
