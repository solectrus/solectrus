class PowerPeak < Flux::Reader
  def result(start:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 30s, fn: mean)
      |> max()
    QUERY

    array = raw
    array.map!(&:records)
    array.map!(&:first)
    array.map!(&:values)

    array.reduce({}) do |total, current|
      total.merge(current['_field'] => current['_value'].round)
    end
  end

  private

  def default_cache_options
    { expires_in: 1.day }
  end
end
