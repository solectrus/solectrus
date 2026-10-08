# The selection of a car on the car page and in the list of the charging
# sessions. The address has the car in front of the page
# (/cars/2/car_charging/2025). A page offers the cars in use in its
# timeframe. Without the car, it shows "all": the sum of the cars, and not
# the sum of the wallbox, because a wallbox session without a car counts for
# no car. An id without an offered car is no selection, and the page goes to
# "all".
#
# The list of the charging sessions also selects the extras of its kind
# (`extras: true`): the wallbox sessions that are not assigned and the guest
# sessions.
class CarSelection
  GUEST = ChargingSession::GUEST
  public_constant :GUEST

  UNASSIGNED = 'unassigned'.freeze
  public_constant :UNASSIGNED

  # The extras of the list of each kind of charging session
  EXTRAS = { 'wallbox' => [UNASSIGNED, GUEST], 'offsite' => [] }.freeze
  public_constant :EXTRAS

  # The car in the address. One digit (see Sensor::Cars::MAX), so it never
  # takes a year like /cars/2025.
  CAR = /\d/
  public_constant :CAR

  CAR_OR_EXTRA = Regexp.union(CAR, *EXTRAS.values.flatten)
  public_constant :CAR_OR_EXTRA

  # Without a timeframe, the page offers each car of the installation
  def initialize(param, timeframe:, extras: false)
    @param = param.presence
    @timeframe = timeframe
    @extras = extras
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

  # One of EXTRAS, when the list selects it
  def extra
    @param if @extras && @param.in?(EXTRAS.values.flatten)
  end

  # The parameter of the selection, nil for "all"
  def to_param
    extra || car&.id&.to_s
  end

  # The parameter in the list of the given kind. The list of the other kind
  # drops an extra, because it has other extras.
  def to_param_for(kind)
    to_param unless extra && EXTRAS[kind].exclude?(extra)
  end

  # Whether the parameter selects something. Otherwise the page goes to
  # "all".
  def valid?
    @param.nil? || to_param.present?
  end

  # The filter of ChargingSession.list_for: a car id, :guest or
  # :unassigned, nil for "all"
  def filter
    extra&.to_sym || car&.id
  end
end
