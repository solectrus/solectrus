# The distance of the selected cars, each car in a column of its own. The
# distance comes from the daily summaries, so a column is a day at least.
class Sensor::Chart::CarMileage < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  def self.supports?(timeframe)
    !timeframe.short?
  end

  def chart_sensor_names
    @chart_sensor_names ||= cars.map { Sensor::Cars.sensor_name(:car_mileage, it.id) }.select { Sensor::Config.exists?(it) }
  end

  # The label of each column names its car
  def label
    I18n.t('sensors.car_mileage')
  end

  private

  def build_data
    super if supported?
  end

  # The columns of the cars stack
  def build_dataset(sensor_name, chart_data)
    super.merge(label: Car.display_name_of(Sensor::Registry[sensor_name].car_number), stack: 'Car-Mileage')
  end
end
