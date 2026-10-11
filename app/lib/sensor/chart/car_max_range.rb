class Sensor::Chart::CarMaxRange < Sensor::Chart::Base
  include Sensor::Chart::Concerns::OneCar

  # car_max_range is a state, so the base class holds its value between two
  # readings -- see #holds_value?.
  def chart_sensor_names
    sensor_names_of(:car_max_range)
  end

  private

  # car_max_range is a derived value (range at current SOC extrapolated to
  # 100%), so averaging is the only sensible meta aggregation.
  def sql_aggregations_for_sensor(_sensor_name)
    %i[avg avg]
  end
end
