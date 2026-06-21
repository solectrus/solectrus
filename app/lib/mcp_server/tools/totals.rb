module McpServer
  module Tools
    # Returns aggregated totals for a timeframe: energy in Wh (summed),
    # percentages/temperatures (averaged), money and CO2. The backend
    # (InfluxDB for hourly, PostgreSQL summaries for day/month/year) is chosen
    # automatically by Sensor::Query::Total based on the timeframe.
    class Totals < Base
      tool_name 'get_totals'
      title 'Get aggregated totals'
      description <<~TEXT.strip
        Get aggregated values for a timeframe: produced/consumed energy (Wh),
        autarky and self-consumption (%), costs, revenue and savings (€), CO₂
        reduction (g). Energy and money are summed over the period, percentages
        and temperatures averaged.

        The `timeframe` uses SOLECTRUS notation, for example:
          "2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month),
          "2026" (a year), "P24H" (last 24 hours), "P30D" (last 30 days),
          "P12M" (last 12 months), "2026-01-01..2026-03-31" (a date range),
          "day"/"week"/"month"/"year" (current period), "all" (since install).

        Pass the sensor machine names from list_sensors via `sensors`.
      TEXT
      input_schema(
        properties: {
          timeframe: {
            type: 'string',
            description:
              'SOLECTRUS timeframe, e.g. "2026-06", "2026", "P24H", "P30D", "2026-01-01..2026-03-31", "month".',
          },
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description: 'List of sensor machine names (from list_sensors).',
          },
        },
        required: %w[timeframe sensors],
      )
      read_only idempotent: true

      def self.call(timeframe:, sensors:, **)
        tf = Timeframe.new(timeframe)
        aggregations =
          resolve_sensors(sensors).index_with(&:default_aggregation)

        data = totals(tf, aggregations)
        json_response(timeframe: tf.to_s, totals: build_totals(data, aggregations))
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.totals(timeframe, aggregations)
        Sensor::Query::Total.new(timeframe) do |q|
          aggregations.each do |sensor, aggregation|
            q.public_send(aggregation, sensor.name) if aggregation
          end
        end.call
      end
      private_class_method :totals

      def self.build_totals(data, aggregations)
        present = data.sensor_names
        aggregations.map do |sensor, aggregation|
          {
            name: sensor.name,
            display_name: sensor.display_name,
            unit: sensor.unit,
            aggregation:,
            value: present.include?(sensor.name) ? data.public_send(sensor.name) : nil,
          }
        end
      end
      private_class_method :build_totals
    end
  end
end
