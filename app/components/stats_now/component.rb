class StatsNow::Component < ViewComponent::Base
  def initialize(data:, sensor:)
    super()
    @data = data
    @sensor = sensor
  end

  attr_accessor :data, :sensor

  def max_flow
    #  Heuristic: The peak flow rate is the highest value
    #  of all fields.
    #
    # If we have no data (e.g. right after installation or
    # resetting the summaries), we assume an estimated value of 5 KW
    @max_flow ||=
      begin
        max_value = peak.values.compact.max.to_i
        max_value.positive? ? max_value : 5000
      end
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||= Sensor::Query::PowerPeak.new(data.sensor_names).call
  end

  # The one car in use today. More cars would not fit into the badge, so
  # only the car page shows them. The controller adds the sensors of this
  # car to the data (see Balance::StatsController#car_sensor_names).
  def car = Car.sole_in_use

  def car_soc = (value(car.sensor_name(:car_battery_soc)) if car)

  def car_connected = value(:wallbox_car_connected)

  private

  def value(sensor_name)
    data.public_send(sensor_name) if data.respond_to?(sensor_name)
  end
end
