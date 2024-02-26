class PowerPeak < Flux::Reader
  def result(start:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 30s, fn: mean)
      |> max()
    QUERY

    array = raw
    array.map!(&:records)
    array.map!(&:first)
    array.map!(&:values)

    array.reduce({}) do |total, current|
      sensor =
        Rails.application.config.x.influx.sensors.find_by(
          current['_measurement'],
          current['_field'],
        )

      total.merge(sensor => current['_value'].round)
    end
  end

  private

  def default_cache_options
    { expires_in: 1.day }
  end
end
