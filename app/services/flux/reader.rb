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
    filter = fields.map do |field|
      "r[\"_field\"] == \"#{field}\""
    end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def measurements_filter
    filter = measurements.map do |measurement|
      "r[\"_measurement\"] == \"#{measurement}\""
    end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def range(start:, stop: nil)
    if stop
      "range(start: #{start}, stop: #{stop})"
    else
      "range(start: #{start})"
    end
  end

  def query(string)
    client.create_query_api.query(query: string)
  end
end
