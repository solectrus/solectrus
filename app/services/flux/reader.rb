class Flux::Reader < Flux::Base
  def initialize(fields:, measurements:)
    super()
    @fields = fields
    @measurements = measurements
    @cache_options = default_cache_options
  end
  attr_reader :fields, :measurements

  private

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

  def query(string)
    if @cache_options
      Rails
        .cache
        .fetch("flux/v2/#{string}", @cache_options) do
          query_without_cache(string)
        end
    else
      query_without_cache(string)
    end
  end

  def query_without_cache(string)
    Rails.logger.debug { "Flux query: #{string}" }

    client.create_query_api.query(query: string)
  end

  def cache_options(stop:)
    # Cache forever if the result cannot change anymore
    return {} if stop&.past?

    default_cache_options
  end

  def default_cache_options
    # Don't cache at all
  end
end
