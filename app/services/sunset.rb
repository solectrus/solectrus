class Sunset < Flux::Reader
  def initialize(date)
    super(
      fields: ['watt'],
      measurements: [Rails.configuration.x.influx.measurement_forecast],
    )
    @date = date
  end

  def time
    @time ||=
      begin
        raw = query <<-QUERY
          #{from_bucket}
          |> #{range(start: @date.beginning_of_day, stop: @date.end_of_day)}
          |> #{measurements_filter}
          |> #{fields_filter}
          |> last()
        QUERY

        array = raw
        array.map!(&:records)
        array.map!(&:first)
        array.map!(&:values)

        Time.zone.parse(array.last['_time'])
      end
  end

  private

  def default_cache_options
    { expires_in: 2.hours }
  end
end
