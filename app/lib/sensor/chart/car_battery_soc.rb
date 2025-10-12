class Sensor::Chart::CarBatterySoc < Sensor::Chart::Base
  def chart_sensor_names
    %i[car_battery_soc]
  end

  def build_sql_series
    Sensor::Query::Sql
      .new do |q|
        q.avg :car_battery_soc, :min
        q.avg :car_battery_soc, :max

        q.timeframe timeframe
        q.group_by sql_grouping_period
      end
      .call
  end

  def build_data
    return super unless use_sql_for_timeframe?

    min_points = series.car_battery_soc(:avg, :min)
    max_points = series.car_battery_soc(:avg, :max)

    # Return nil if no data available
    return if min_points.blank? || max_points.blank?

    labels = []
    data = []

    min_points.each do |timestamp, min_val|
      labels << (timestamp.to_time.to_i * 1000)
      data << [min_val, max_points[timestamp]]
    end

    # Return nil if no data points were collected
    return if data.blank?

    sensor = Sensor::Registry[:car_battery_soc]
    {
      labels:,
      datasets: [{ **style_for_sensor(sensor), id: sensor.name, data: }],
    }
  end
end
