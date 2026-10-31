# The distance of the selected cars, each car in a part of its own, from the
# daily summaries, so a column is a day at least. A day has the timeline of
# the day instead (see Car::Section.charts?).
class Sensor::Chart::CarDistance < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars
  include Sensor::Chart::Concerns::BlankWithoutPositive

  def self.supports?(timeframe)
    !timeframe.short?
  end

  # Only a car with an odometer has a distance
  def supported?
    super && cars.any? { it.sensor?(:car_odometer) }
  end

  # The daily values hold no value outside the period of use of a car (see
  # Sensor::Summarizer)
  def chart_sensor_names
    @chart_sensor_names ||= cars.select { it.sensor?(:car_odometer) }.map { it.sensor_name(:car_odometer) }
  end

  # The label of each part names its car
  def label
    I18n.t('sensors.car_distance')
  end

  def blank_message = no_driving_message

  def blank_icon = 'road'

  # A part has the color of the distance, not of the odometer that gives its
  # values. It stays public, like in Sensor::Chart::Base.
  def color_class(_sensor) = Sensor::Registry[:car_distance].color_background

  private

  # A timeframe without a car in use has no distance
  def build_data
    super if chart_sensor_names.any?
  end

  # Several cars tint each part with the color of their car. The columns of
  # the cars stack.
  def build_dataset(sensor_name, chart_data)
    car_number = Sensor::Registry[sensor_name].car_number
    tint_color = cars.find { it.id == car_number }&.display_color if cars.many?

    super.merge(label: Car.display_name_of(car_number), tintColor: tint_color, stack: 'CarDistance', summed: true).compact
  end
end
