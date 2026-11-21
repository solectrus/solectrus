module Sensor
  module Chart
    module Concerns
      # The PV forecast for the rest of today, as a hatched area next to the
      # measured area of a stacked chart. Before now, the measured area shows,
      # so the forecast begins at the last bucket before now.
      module RemainingForecast
        private

        # The hatched area has the line of the forecast as its edge
        def remaining_forecast_style(sensor)
          Base::FORECAST_LINE_STYLE.merge(
            tension: 0.4,
            cubicInterpolationMode: 'monotone',
            colorClass: sensor.color_background,
            fill: true,
            noGradient: true,
            hatchFill: true,
            pointRadius: 0,
          )
        end

        def build_remaining_forecast_data_item(sensor_name)
          return empty_dataset(sensor_name) unless series.respond_to?(sensor_name)

          aggregations = aggregations_for_sensor(sensor_name)
          points_hash = series.public_send(sensor_name, *aggregations)
          return empty_dataset(sensor_name) unless points_hash

          sorted_points = points_hash.sort_by { |time_key, _| time_key }
          labels = sorted_points.map { |time_key, _| timestamp_to_ms(time_key) }
          data_values = transform_data(sorted_points.map(&:second), sensor_name)

          {
            sensor_name:,
            labels:,
            data: mask_past_forecast_values(sorted_points, data_values),
          }
        end

        # Hide forecast values before now, but seed the last bucket before it -
        # the one where the measured area hands over to the forecast - so the
        # forecast starts there instead of leaving a wedge until the next
        # provider sample.
        def mask_past_forecast_values(sorted_points, data_values)
          now = Time.current
          normalized = sorted_points.map { |time_key, _| normalize_timestamp(time_key) }
          future_idx = normalized.index { |timestamp| timestamp > now } || normalized.size
          # -1 when nothing precedes now: no bucket to seed, and no index matches
          seed_idx = future_idx - 1

          data_values.map.with_index do |value, idx|
            if idx >= future_idx
              value
            elsif idx == seed_idx
              forecast_at(normalized, data_values, idx)
            end
          end
        end

        # Forecast at +index+, interpolated between the nearest samples on
        # either side. The seeded bucket is the only point where the forecast
        # area touches the measured one, so it has to carry the forecast for
        # its own timestamp: copying the next sample back-dates it by up to a
        # provider cadence (15 min) and offsets the whole handover along the
        # forecast curve.
        def forecast_at(timestamps, values, index)
          return values[index] if values[index]

          before = (index - 1).downto(0).find { |i| values[i] }
          after = ((index + 1)...values.size).find { |i| values[i] }
          return after && values[after] if before.nil?
          return values[before] if after.nil?

          linear_interpolate(timestamps, values, before, after, index)
        end
      end
    end
  end
end
