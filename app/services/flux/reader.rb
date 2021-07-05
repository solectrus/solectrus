class Flux::Reader < Flux::Base
  def initialize(fields:, measurements:)
    super()
    @fields = fields
    @measurements = measurements
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
    start = start.iso8601 if start.respond_to?(:iso8601)
    stop = stop.iso8601 if stop.respond_to?(:iso8601)

    stop ? "range(start: #{start}, stop: #{stop})" : "range(start: #{start})"
  end

  def query(string)
    client.create_query_api.query(query: string)
  end
end
