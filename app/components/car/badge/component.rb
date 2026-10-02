# The holder of a charging session in the list: the car in its color, a
# guest, or "not assigned", which is an open task.
class Car::Badge::Component < ViewComponent::Base
  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

  delegate :state, to: :charging_session

  def label
    case state
    when :car then charging_session.car.display_name
    when :guest then t('.guest')
    else t('.not_assigned')
    end
  end

  def color
    charging_session.car.display_color if state == :car
  end
end
