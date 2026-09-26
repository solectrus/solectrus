class Sensor::Chart::MinmaxBase < Sensor::Chart::Base
  # MinMax charts display min/max ranges as bars
  # Subclasses only need to implement:
  # - chart_sensor_names (returns array with single sensor name)
  # - suggested_min (optional)

  # Pixels
  MIN_BAR_LENGTH = 2
  private_constant :MIN_BAR_LENGTH

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

  def build_data
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
      data << bar(min_val, max_points[timestamp])
    end

    # Return nil if no data points were collected
    return if data.blank?

    sensor = Sensor::Registry[sensor_name]
    {
      labels:,
      datasets: [
        {
          **style_for_sensor(sensor),
          id: sensor.name,
          data:,
          # Keeps a bar visible where min equals max. The data stays exact, so
          # the tooltip shows a single value instead of a made-up range.
          minBarLength: MIN_BAR_LENGTH,
          # At the edge of the axis (a SOC of 100 %) such a bar leaves the
          # chart area, and Chart.js would cut it off
          clip: MIN_BAR_LENGTH,
        },
      ],
    }
  end

  # MinMax charts should have rounded corners on all sides
  def bar_border_skip # rubocop:disable Naming/PredicateMethod
    false
  end

  private

  # Chart.js reads a missing end as 0, which minBarLength would draw, so a
  # period without both ends has no bar at all
  def bar(min_val, max_val)
    [min_val, max_val] if min_val && max_val
  end
end
