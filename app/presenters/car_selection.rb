# The selection of a car on the car page, in the list of the charging
# sessions and in the list of the visits. The address has the car in front of
# the page (/cars/2/car_charging/2025). A page offers the cars in use in its
# timeframe. Without the car, it shows "all": the sum of the cars and of the
# guest, and not the sum of the wallbox, because a session that is not
# assigned counts for no car. An id without an offered car is no selection,
# and the page goes to "all".
#
# The list of the charging sessions also selects the extras of its kind
# (`extras: true`): the wallbox sessions that are not assigned and the guest
# sessions, or the proposals of the offsite sessions.
#
# The car page also selects the guest sessions (`guest: true`, see
# #guest?). They belong to no car, so their selection has no car.
class CarSelection
  GUEST = ChargingSession::GUEST
  public_constant :GUEST

  UNASSIGNED = 'unassigned'.freeze
  public_constant :UNASSIGNED

  PROPOSALS = 'proposals'.freeze
  public_constant :PROPOSALS

  # The extras of the list of each kind of charging session
  EXTRAS = { 'wallbox' => [UNASSIGNED, GUEST], 'offsite' => [PROPOSALS] }.freeze
  public_constant :EXTRAS

  # The car in the address. One digit (see Sensor::Cars::MAX), so it never
  # takes a year like /cars/2025.
  CAR = /\d/
  public_constant :CAR

  CAR_OR_EXTRA = Regexp.union(CAR, *EXTRAS.values.flatten)
  public_constant :CAR_OR_EXTRA

  # The car page selects a car or the guests
  CAR_OR_GUEST = Regexp.union(CAR, GUEST)
  public_constant :CAR_OR_GUEST

  # Without a timeframe, the page offers each car of the installation
  def initialize(param, timeframe:, extras: false, guest: false)
    @param = param.presence
    @timeframe = timeframe
    @extras = extras
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

  # The selected car, or nil for "all"
  def car
    return @car if defined?(@car)

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

  # One of EXTRAS, when the list selects it
  def extra
    @param if @extras && @param.in?(EXTRAS.values.flatten)
  end

  # The parameter of the selection, nil for "all"
  def to_param
    extra || (GUEST if guest?) || car&.id&.to_s
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

  # The filter of ChargingSession.list_for: a car id, :guest, :unassigned or
  # :proposals, nil for "all"
  def filter
    extra&.to_sym || car&.id
  end
end
