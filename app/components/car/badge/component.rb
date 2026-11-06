# The holder of a charging session in the list: the car in its color, a
# guest, or a question mark for "not assigned", which is an open task (see
# ChargingSession::ReviewBadge::Component). With a car instead of a session,
# the badge shows that car.
class Car::Badge::Component < ViewComponent::Base
  def initialize(charging_session: nil, car: nil, short: false)
    super()
    @charging_session = charging_session
    @car = car || charging_session&.car
    @short = short
  end

  # A short badge names the car by its short name, and its title by the full
  # name
  def short? = @short

  attr_reader :charging_session, :car

  def state
    charging_session ? charging_session.state : :car
  end

  def label
    case state
    when :car then short? ? car.short_name : car.display_name
    when :guest then t('.guest')
    else t('.unassigned')
    end
  end

  def color
    car.display_color if state == :car
  end

  def title
    car.display_name if short? && state == :car
  end

  def css_class
    'inline-flex items-center max-w-full rounded-full gap-1.5 px-2 py-0.5 text-xs sm:text-sm bg-fill text-fg-secondary'
  end
end
