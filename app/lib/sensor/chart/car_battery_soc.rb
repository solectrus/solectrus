class Sensor::Chart::CarBatterySoc < Sensor::Chart::MinmaxBase
  include Sensor::Chart::Concerns::OneCar

  # car_battery_soc is a state, so the base class holds its value between
  # two readings -- see #holds_value?.
  def chart_sensor_names
    sensor_names_of(:car_battery_soc)
  end
end
