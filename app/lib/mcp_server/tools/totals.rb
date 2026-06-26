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
        Get aggregated values for a timeframe: produced/consumed energy,
        autarky and self-consumption (%), costs, revenue and savings (€), CO₂
        reduction. Energy and money are summed over the period, percentages
        and temperatures averaged.

        IMPORTANT — units after aggregation: summing a power sensor (unit
        "watt") yields an ENERGY, not a power. So its `value` is in Wh, not W
        (divide by 1000 for kWh) — never read a watt-sum as a power. All other
        units aggregate unchanged.

        The `timeframe` uses SOLECTRUS notation, for example:
          "2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month),
          "2026" (a year), "P24H" (last 24 hours), "P30D" (last 30 days),
          "P12M" (last 12 months), "2026-01-01..2026-03-31" (a date range),
          "day"/"week"/"month"/"year" (current period), "all" (since install).

        Pass the sensor names from list_sensors via `sensors`.

        This tool is for historical measured or aggregated actual values. Do NOT
        pass forecast sensors (e.g. "inverter_power_forecast") — those are
        rejected, since the summaries hold no forecast. For the expected PV
        generation forecast, use get_forecast.
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
            description: 'List of sensor names (from list_sensors).',
          },
        },
        required: %w[timeframe sensors],
      )
      read_only idempotent: true

      def self.call(timeframe:, sensors:, **)
        tf = Timeframe.new(timeframe)
        resolved = resolve_sensors(sensors)

        forecast = resolved.select(&:forecast?)
        if forecast.any?
          return error_response(
            "Forecast sensors (#{forecast.map(&:name).join(', ')}) are not " \
              'supported by get_totals. Use get_forecast for the expected PV ' \
              'generation forecast.',
          )
        end

        aggregations = resolved.index_with(&:default_aggregation)

        data = totals(tf, aggregations)
        json_response(timeframe: tf.to_s, totals: build_totals(data, aggregations))
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.totals(timeframe, aggregations)
        # Only sensors with a natural aggregation can drive the SQL/Influx query.
        # Aggregation-less derived sensors (e.g. chart-only pseudo-sensors) carry
        # no total of their own; skip them here so they don't collapse the query
        # to an empty sensor list and trip the "cannot be empty" guard. They are
        # still reported (as nil, or as a computed value if a queried sibling
        # pulls them in as a dependency) by build_totals.
        queryable = aggregations.compact
        return if queryable.empty?

        Sensor::Query::Total.new(timeframe) do |q|
          queryable.each do |sensor, aggregation|
            q.public_send(aggregation, sensor.name)
          end
        end.call
      end
      private_class_method :totals

      def self.build_totals(data, aggregations)
        present = data ? data.sensor_names : []
        aggregations.map do |sensor, aggregation|
          value =
            if present.include?(sensor.name)
              format_value(sensor, data.public_send(sensor.name))
            end

          {
            name: sensor.name,
            display_name: sensor.display_name,
            unit: sensor.unit,
            aggregation:,
            value:,
          }
        end
      end
      private_class_method :build_totals

      # Normalize the reported value. Percentages are rounded to a whole
      # percent so every percent-unit sensor (autarky, self_consumption_quote,
      # grid_quote, ...) is reported consistently, regardless of whether its own
      # calculation already rounded.
      def self.format_value(sensor, value)
        return value.round if sensor.unit == :percent && value.is_a?(Numeric)

        value
      end
      private_class_method :format_value
    end
  end
end
