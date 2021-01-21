class Flux::Reader < Flux::Base
  def initialize(*fields)
    super()
    @fields = fields
  end
  attr_reader :fields

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

  def measurement_filter
    "filter(fn: (r) => r[\"_measurement\"] == \"#{measurement}\")"
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

  def measurement
    raise NotImplementedError
  end
end
