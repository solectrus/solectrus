# The selection of a car on the car page. The address has the car in front of
# the page (/cars/2/car_charging/2025). A page offers the cars in use in its
# timeframe. Without the car, it shows "all": the sum of the cars, and not the
# sum of the wallbox, because a wallbox session without a car counts for no
# car. An id without an offered car is no selection, and the page goes to
# "all".
class CarSelection
  # The car in the address. One digit (see Sensor::Cars::MAX), so it never
  # takes a year like /cars/2025.
  CAR = /\d/
  public_constant :CAR

  # Without a timeframe, the page offers each car of the installation
  def initialize(param, timeframe:)
    @param = param.presence
    @timeframe = timeframe
  end

  # The cars of the installation, also the cars outside the timeframe
  def installed
    @installed ||= Car.configured
  end

  # The cars that the page offers: the cars in use in the timeframe. The live
  # view therefore offers the cars in use today.
  def offered
    @offered ||= @timeframe ? installed.select { it.active_during?(@timeframe.effective_dates) } : installed
  end

  # The selected car, or nil for "all"
  def car
    return @car if defined?(@car)

    id = Integer(@param, exception: false)
    @car = offered.find { it.id == id }
  end

  # The cars the page shows
  def cars
    car ? [car] : offered
  end

  # The parameter of the selection, nil for "all"
  def to_param
    car&.id&.to_s
  end

  # Whether the parameter selects something. Otherwise the page goes to
  # "all".
  def valid?
    @param.nil? || to_param.present?
  end
end
