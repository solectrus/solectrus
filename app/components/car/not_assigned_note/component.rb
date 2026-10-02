# The note of the selection "all" about the wallbox sessions of the period
# that are not assigned to a car. They count for no car, so without the note
# the numbers of "all" are too small without a reason. The note links to the
# list of these sessions.
class Car::NotAssignedNote::Component < ViewComponent::Base
  # `all` is whether the page shows "all" and not one selected car
  def initialize(balance:, timeframe:, all:)
    super()
    @balance = balance
    @timeframe = timeframe
    @all = all
  end

  attr_reader :balance, :timeframe

  def render?
    @all && totals[:count].positive?
  end

  def totals
    balance.session_totals(:not_assigned)
  end

  def path
    helpers.charging_sessions_path(kind: 'wallbox', timeframe:, car: ChargingSessionList::CarFilter::NOT_ASSIGNED)
  end

  def energy
    SensorValue::Component.new(totals[:wh], :wallbox_power, context: :total, scaling: :kilo, precision: 1)
  end
end
