# The car filter of the list of the charging sessions: one car, all, and for
# the wallbox sessions also the sessions that are not assigned and the guest
# sessions. The list carries it as a parameter (?car=2, ?car=not_assigned).
class ChargingSessionList::CarFilter
  NOT_ASSIGNED = 'not_assigned'.freeze
  public_constant :NOT_ASSIGNED

  GUEST = 'guest'.freeze
  public_constant :GUEST

  # An id without a car shows all sessions
  def self.from_param(value, cars:)
    return new(value) if value.in?([NOT_ASSIGNED, GUEST])

    car_id = Integer(value, exception: false)
    new(cars.find { it.id == car_id }&.id&.to_s)
  end

  def initialize(param)
    @param = param
  end

  def to_param = @param

  # The parameter in the list of the given kind. An offsite session has no
  # filter for the sessions that are not assigned and the guest sessions.
  def to_param_for(kind)
    @param if kind == 'wallbox' || !@param.in?([NOT_ASSIGNED, GUEST])
  end

  # The value of ChargingSession.list_for
  def scope_value
    case @param
    when NOT_ASSIGNED then :not_assigned
    when GUEST then :guest
    when nil then nil
    else @param.to_i
    end
  end
end
