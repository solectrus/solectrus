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
        and temperatures averaged. Each entry reports the `unit` it carries
        AFTER that aggregation — a summed watt sensor reports watt_hour.

        Historical, measured actuals only: a forecast sensor (e.g.
        "inverter_power_forecast") is rejected, since the summaries hold no
        forecast. Use get_forecast for the expected PV generation.

        A null `value` means the timeframe holds no data for that sensor, never
        that the sensor is the wrong one to ask: a sensor with no aggregation
        at all carries no "t" in its `tools` and is rejected by name.
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
        enforce_aggregatable!(resolved, 'get_totals')

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

      # Every sensor here has a natural aggregation - enforce_aggregatable!
      # rejected the rest - so the query can never collapse to an empty sensor
      # list and trip the "cannot be empty" guard.
      def self.totals(timeframe, aggregations)
        Sensor::Query::Total.new(timeframe) do |q|
          aggregations.each do |sensor, aggregation|
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
