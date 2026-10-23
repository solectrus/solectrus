# The selection of a car on the car page, in the lists of the charging
# sessions and of the visits. The address has the car in front of
# the page (/cars/2/car_charging/2025). A page offers the cars in use in its
# timeframe. Without the car, it shows "all": the sum of the cars and of the
# guest, and not the sum of the wallbox, because a session that is not
# assigned counts for no car. An id without an offered car is no selection,
# and the page goes to "all".
#
# The car page and the list of the charging sessions also select the guest
# sessions (`guest: true`, see #guest?). They belong to no car, so their
# selection has no car.
class CarSelection
  GUEST = ChargingSession::GUEST
  public_constant :GUEST

  # The car in the address. One digit (see Sensor::Cars::MAX), so it never
  # takes a year like /cars/2025.
  CAR = /\d/
  public_constant :CAR

  # The car page selects a car or the guests
  CAR_OR_GUEST = Regexp.union(CAR, GUEST)
  public_constant :CAR_OR_GUEST

  # Without a timeframe, the page offers each car of the installation
  def initialize(param, timeframe:, guest: false)
    @param = param.presence
    @timeframe = timeframe
    @guest = guest
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

  # The selected car, or nil for "all". The live view shows each car in use,
  # so it selects none, and a car in its address goes to "all".
  def car
    return @car if defined?(@car)
    return @car = nil if @timeframe&.now?

    id = Integer(@param, exception: false)
    @car = offered.find { it.id == id }
  end

  # Whether the page offers the guest sessions: once the wallbox has one. A
  # period without one shows no charge, so the selection stays when the
  # timeframe changes.
  def guest_offered?
    return @guest_offered if defined?(@guest_offered)

    @guest_offered = @guest && Sensor::Config.exists?(:wallbox_power) && ChargingSession.wallbox.effective.exists?(guest: true)
  end

  # Whether the page shows the guest sessions. The live view shows the cars
  # in use, so it has no guests.
  def guest?
    @param == GUEST && !@timeframe&.now? && guest_offered?
  end

  # Whether the guest sessions count: for the guest and for "all"
  def with_guest?
    guest? || car.nil?
  end

  # The cars the page shows, none for the guest sessions
  def cars
    return [] if guest?

    car ? [car] : offered
  end

  # The parameter of the selection, nil for "all"
  def to_param
    (GUEST if guest?) || car&.id&.to_s
  end

  # Whether the parameter selects something. Otherwise the page goes to
  # "all".
  def valid?
    @param.nil? || to_param.present?
  end

  # The filter of ChargingSession.list_for: a car id or :guest, nil for "all"
  def filter
    guest? ? :guest : car&.id
  end
end
