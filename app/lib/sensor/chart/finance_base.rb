class Sensor::Chart::FinanceBase < Sensor::Chart::Base
  # The money values themselves come from the sensor definitions: Query::Series
  # (short timeframes) and Query::Total (SQL) calculate them, so a finance chart
  # only has to name its sensor in #chart_sensor_names -- see
  # Sensor::Query::Helpers::Influx::FinanceCalculation. Unit (:money) and scaling
  # follow from that sensor, so Sensor::Chart::Base derives them by itself.
  def permitted_feature_name
    :finance_charts
  end
end
