# The switch between the charging card and the driving card on a phone,
# where the two cards do not fit side by side (see car_cards_controller.ts).
# The card follows the chart: the charging card belongs to the charged energy
# and its cost, the driving card to every other chart. The stats render the
# switch once, and each chart renders it again for its sensor, so a chart of
# the other card shows that card. The pressed button shows its card (see the
# stats).
class Car::CardToggle::Component < ViewComponent::Base
  CARDS = %w[charging driving].freeze
  public_constant :CARDS

  CHARGING_SENSORS = %i[car_charging car_charging_costs].freeze
  private_constant :CHARGING_SENSORS

  def initialize(sensor_name:)
    super()
    @sensor_name = sensor_name
  end

  def card
    CHARGING_SENSORS.include?(@sensor_name&.to_sym) ? 'charging' : 'driving'
  end
end
