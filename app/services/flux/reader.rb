class Flux::Reader < Flux::Base
  def initialize(fields:, measurements:)
    super()
    @fields = fields
    @measurements = measurements
    @cache_options = default_cache_options
  end
  attr_reader :fields, :measurements

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

  def fields_filter
    filter = fields.map { |field| "r[\"_field\"] == \"#{field}\"" }

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def measurements_filter
    filter =
      measurements.map do |measurement|
        "r[\"_measurement\"] == \"#{measurement}\""
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
    # Don't cache at all
  end
end
