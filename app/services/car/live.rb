# The live view of the car page: the state of each selected car with its own
# plug, and the charging power and the plug of the wallbox. A car outside its
# period of use has no state.
class Car::Live
  # The state of one car. `charging_power` is the power of the wallbox for the
  # car at the wallbox, and zero for any other car with a plug. `time` is the
  # latest reading of the car. A car sensor holds its value at any age (see
  # the DSL `state`), so the time tells how old the state is.
  State =
    Data.define(:car, :soc, :range, :max_range, :odometer, :connected, :charging_power, :latitude, :longitude, :time) do
      def initialize(time: nil, **) = super

      # [latitude, longitude], or nil without both
      def location = ([latitude, longitude] if latitude && longitude)
    end
  public_constant :State

  ROLES = {
    soc: :car_battery_soc,
    range: :car_range,
    max_range: :car_max_range,
    odometer: :car_odometer,
    connected: :car_connected,
    latitude: :car_latitude,
    longitude: :car_longitude,
  }.freeze
  private_constant :ROLES

  WALLBOX_SENSORS = %i[wallbox_power wallbox_car_connected].freeze
  private_constant :WALLBOX_SENSORS

  # `home` is the place of the wallbox, or nil (see Place.home)
  def initialize(cars, home: Place.home)
    @cars = cars
    @home = home
  end

  attr_reader :cars

  # The latest values, as Sensor::Data::Single, for SensorValue::Component
  def data
    @data ||= Sensor::Query::Latest.new([*WALLBOX_SENSORS, *cars.flat_map { |car| ROLES.values.map { car.sensor_name(it) } }]).call
  end

  delegate :time, to: :data

  def wallbox_power = value(:wallbox_power)

  def wallbox_car_connected = value(:wallbox_car_connected)

  # The state of each car. Each car with a plug gets a charging power next to
  # it: the car at the wallbox the power of the wallbox, any other car zero.
  def states
    @states ||= own_states.map { it.with(charging_power: charging_power_of(it)) }
  end

  # Whether the live view knows the car at the wallbox. Without such a car,
  # the wallbox shows its power itself.
  def car_at_wallbox? = !car_at_wallbox.nil?

  private

  attr_reader :home

  def cars_in_use
    @cars_in_use ||= cars.select { it.active_on?(Date.current) }
  end

  # The state of each car from its own sensors
  def own_states
    @own_states ||= cars.map { state_of(it) }
  end

  # One car in use without a plug of its own shows the plug of the wallbox,
  # because the live view has no other car to show it.
  def state_of(car)
    in_use = car.in?(cars_in_use)
    state = State.new(car:, charging_power: nil, time: (time_of(car) if in_use), **ROLES.transform_values { value(car.sensor_name(it)) if in_use })
    state = state.with(latitude: nil, longitude: nil) if left_location?(car, state)
    in_use && cars_in_use.one? && state.connected.nil? ? state.with(connected: wallbox_car_connected) : state
  end

  # Whether the car drove away from its latest position: its odometer rose
  # by more than Sensor::Query::Positions::MOVE since then. A position holds
  # at any age, so a source that stopped to send it would else show a place
  # where the car is no more.
  def left_location?(car, state)
    odometer = car.sensor_name(:car_odometer)
    position_time = data.time_for(car.sensor_name(:car_latitude))
    odometer_time = data.time_for(odometer)
    return false unless state.location && state.odometer && position_time && odometer_time && odometer_time > position_time

    at_position = Sensor::Query::Positions.odometer_at(odometer, position_time)
    at_position.present? && Sensor::Query::Positions.left?(at_position, state.odometer)
  end

  def charging_power_of(state)
    return if wallbox_power.nil?

    if state.equal?(car_at_wallbox)
      wallbox_power
    elsif !state.connected.nil?
      0
    end
  end

  # The car at the wallbox: a car in use that is at home, with the wallbox
  # and the car both connected. A missing value gives no sign, like in
  # ChargingSession::Detection::CarAssignment: the wallbox without a plug,
  # a car without a plug or a position, or no home. Of the remaining cars,
  # the one car that reports a connection, or else the one car.
  def car_at_wallbox
    return @car_at_wallbox if defined?(@car_at_wallbox)

    @car_at_wallbox =
      unless wallbox_car_connected == false
        remaining = candidates.select(&:connected).presence || candidates
        remaining.first if remaining.one?
      end
  end

  # The cars in use that can be at the wallbox
  def candidates
    own_states.select { it.car.in?(cars_in_use) && it.connected != false && !away?(it) }
  end

  # Whether the car reports a position outside the radius of home
  def away?(state)
    home && state.location && !home.covers?(*state.location)
  end

  # The latest reading of a sensor of the car
  def time_of(car)
    ROLES.values.filter_map { data.time_for(car.sensor_name(it)) }.max
  end

  def value(sensor_name)
    data.public_send(sensor_name) if data.respond_to?(sensor_name)
  end
end
