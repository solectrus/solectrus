class Flux::Reader < Flux::Base
  def initialize(fields:, measurements:)
    super()
    @fields = fields
    @measurements = measurements
    @cacheable = false
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
    # Cache only if the range is in the past, so the query result will not change
    @cacheable = stop&.past?

    start = start&.iso8601
    stop = stop&.iso8601

    stop ? "range(start: #{start}, stop: #{stop})" : "range(start: #{start})"
  end

  def query(string, cache_options: {})
    if @cacheable || cache_options.present?
      Rails
        .cache
        .fetch("flux/v2/#{string}", cache_options) do
          query_without_cache(string)
        end
    else
      query_without_cache(string)
    end
  end

  def query_without_cache(string)
    client.create_query_api.query(query: string)
  end
end
