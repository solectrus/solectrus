class Sensor::Chart::HeatpumpTankTemp < Sensor::Chart::Base
  def chart_sensor_names
    %i[heatpump_tank_temp]
  end

  def suggested_min
    20
  end

  def build_sql_series
    Sensor::Query::Sql
      .new do |q|
        q.avg :heatpump_tank_temp, :min
        q.avg :heatpump_tank_temp, :max

        q.timeframe timeframe
        q.group_by sql_grouping_period
      end
      .call
  end

  def build_data
    return super unless use_sql_for_timeframe?

    min_points = series.heatpump_tank_temp(:avg, :min)
    max_points = series.heatpump_tank_temp(:avg, :max)

    labels = []
    data = []

    min_points.each do |timestamp, min_val|
      labels << (timestamp.to_time.to_i * 1000)
      data << [min_val, max_points[timestamp]]
    end

    sensor = Sensor::Registry[:heatpump_tank_temp]
    {
      labels:,
      datasets: [{ **style_for_sensor(sensor), id: sensor.name, data: }],
    }
  end
end
