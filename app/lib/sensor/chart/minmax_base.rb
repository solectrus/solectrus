class Sensor::Chart::MinmaxBase < Sensor::Chart::Base
  # MinMax charts display min/max ranges as bars
  # Subclasses only need to implement:
  # - chart_sensor_names (returns array with single sensor name)
  # - suggested_min (optional)

  def build_sql_series
    sensor_name = chart_sensor_names.first

    Sensor::Query::Total
      .new(timeframe) do |q|
        q.avg sensor_name, :min
        q.avg sensor_name, :max
        q.group_by sql_grouping_period
      end
      .call
  end

  def build_data # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return super unless use_sql_for_timeframe?

    sensor_name = chart_sensor_names.first
    min_points = series.public_send(sensor_name, :avg, :min)
    max_points = series.public_send(sensor_name, :avg, :max)

    # Return nil if no data available
    return if min_points.blank? || max_points.blank?

    labels = []
    data = []

    min_points.each do |timestamp, min_val|
      labels << (timestamp.to_time.to_i * 1000)
      max_val = max_points[timestamp]

      # Ensure a visible bar when min == max by adding a tiny offset
      # (to avoid zero-height bars)
      if min_val && max_val && min_val == max_val
        if max_val < 100
          max_val += 0.4
        else
          min_val -= 0.4
        end
      end

      data << [min_val, max_val]
    end

    # Return nil if no data points were collected
    return if data.blank?

    sensor = Sensor::Registry[sensor_name]
    {
      labels:,
      datasets: [{ **style_for_sensor(sensor), id: sensor.name, data: }],
    }
  end

  # MinMax charts should have rounded corners on all sides
  def bar_border_skip # rubocop:disable Naming/PredicateMethod
    false
  end
end
