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
        autarky and self-consumption (%), costs, revenue and savings (money),
        CO₂ reduction. Energy and money are summed over the period, percentages
        and temperatures averaged.

        IMPORTANT — units after aggregation: #{Facts::WATT_SUM_IS_ENERGY}

        #{Facts::UNKNOWN_SENSORS}

        #{Facts::TIMEFRAME_NOTE}

        This tool is for historical measured or aggregated actual values. Do NOT
        pass forecast sensors (e.g. "inverter_power_forecast") — those are
        rejected, since the summaries hold no forecast. For the expected PV
        generation forecast, use get_forecast.
      TEXT
      input_schema(
        properties: {
          timeframe: timeframe_property('The period to aggregate over.'),
          sensors: sensors_property('List of sensor names (from list_sensors).'),
        },
        required: %w[timeframe sensors],
      )
      read_only idempotent: true

      def self.perform(timeframe:, sensors:, **)
        tf = parse_timeframe(timeframe)
        resolved, unknown = resolve_sensors(sensors)
        reject_forecast!(resolved)

        aggregations = resolved.index_with(&:default_aggregation)

        {
          **timeframe_preamble(tf, unknown),
          totals: build_totals(totals(tf, aggregations), aggregations),
        }
      end

      def self.reject_forecast!(resolved)
        forecast = resolved.select(&:forecast?)
        return if forecast.none?

        raise ArgumentError,
              "Forecast sensors (#{forecast.map(&:name).join(', ')}) are not " \
                'supported by get_totals. Use get_forecast for the expected PV ' \
                'generation forecast.'
      end
      private_class_method :reject_forecast!

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
          unit = mcp_unit(sensor, aggregation)
          value = data.public_send(sensor.name) if present.include?(sensor.name)

          {
            name: sensor.name,
            display_name: sensor.display_name,
            unit:,
            aggregation:,
            value: Precision.round(value, unit),
          }
        end
      end
      private_class_method :build_totals
    end
  end
end
