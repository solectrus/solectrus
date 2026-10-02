# The select of the car above the list of the charging sessions: one car,
# "all", and for the wallbox sessions also "not assigned" and "guest". "all"
# shows each session, also a guest session and a session that is not
# assigned.
class ChargingSession::Filter::Component < ViewComponent::Base
  def initialize(kind:, timeframe:, cars:, current:)
    super()
    @kind = kind
    @timeframe = timeframe
    @cars = cars
    @current = current
  end

  attr_reader :kind, :timeframe, :cars, :current

  def render?
    choices.size > 2
  end

  # [label, parameter, color] of each choice
  def choices
    @choices ||= [
      [t('.all'), nil, nil],
      *cars.map { [it.display_name, it.id.to_s, it.display_color] },
      *(if kind == 'wallbox'
          [
[t('.not_assigned'), ChargingSessionList::CarFilter::NOT_ASSIGNED, nil],
[t('.guest'), ChargingSessionList::CarFilter::GUEST, nil],
]
        end),
    ]
  end

  def items
    choices.map do |label, param, color|
      PillNav::Component::Item.new(
        label:,
        href: helpers.charging_sessions_path(kind:, timeframe:, car: param),
        current: current == param,
        color:,
      )
    end
  end
end
