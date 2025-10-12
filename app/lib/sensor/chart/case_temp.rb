class Sensor::Chart::CaseTemp < Sensor::Chart::Base
  def chart_sensor_names
    %i[case_temp]
  end

  def suggested_min
    10
  end

  def build_sql_series
    Sensor::Query::Sql
      .new do |q|
        q.avg :case_temp, :min
        q.avg :case_temp, :max

        q.timeframe timeframe
        q.group_by sql_grouping_period
      end
      .call
  end

  def build_data
    return super unless use_sql_for_timeframe?

    min_points = series.case_temp(:avg, :min)
    max_points = series.case_temp(:avg, :max)

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

    sensor = Sensor::Registry[:case_temp]
    {
      labels:,
      datasets: [{ **style_for_sensor(sensor), id: sensor.name, data: }],
    }
  end
end
