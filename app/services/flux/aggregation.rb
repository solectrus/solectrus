class Flux::Aggregation < Flux::Reader
  def call(timeframe: nil, start: nil, stop: nil)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    start ||=
      timeframe&.beginning ||
        raise(ArgumentError, 'start or timeframe required')
    stop ||= timeframe&.beginning_of_next

    run_query(start:, stop:)
  end

  private

  def run_query(start:, stop: nil)
    query(build_query(start:, stop:)).each_with_object({}) do |table, hash|
      record = table.records.first

      sensor =
        SensorConfig.x.find_by(
          record.values['_measurement'],
          record.values['_field'],
        )

      hash[:"min_#{sensor}"] = record.values['min']
      hash[:"max_#{sensor}"] = record.values['max']
      hash[:"mean_#{sensor}"] = record.values['mean']
    end
  end

  def build_query(start:, stop:)
    <<~QUERY
      commonQuery = () =>
        #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter}
        |> aggregateWindow(every: 5m, fn: mean)

      minQuery = commonQuery()
        |> min()
        |> set(key: "operation", value: "min")
        |> keep(columns: ["_value", "operation", "_field", "_measurement"])

      maxQuery = commonQuery()
        |> max()
        |> set(key: "operation", value: "max")
        |> keep(columns: ["_value", "operation", "_field", "_measurement"])

      meanQuery = commonQuery()
        |> mean()
        |> set(key: "operation", value: "mean")
        |> keep(columns: ["_value", "operation", "_field", "_measurement"])

      union(tables: [minQuery, maxQuery, meanQuery])
        |> pivot(rowKey:["_field", "_measurement"], columnKey: ["operation"], valueColumn: "_value")
    QUERY
  end
end
