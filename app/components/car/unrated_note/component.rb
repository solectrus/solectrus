# A note in a tooltip of the driving cost or a rate: the kilometers of the
# period on days without a rate. The card shows them in its distance, but the
# calculation leaves them out (see Car::DailyRates).
class Car::UnratedNote::Component < ViewComponent::Base
  def initialize(distance:, rated_distance:)
    super()
    @distance = distance
    @rated_distance = rated_distance
  end

  def render?
    unrated_distance.positive?
  end

  def text
    t('.text', distance: Sensor::ValueFormatter.new(unrated_distance, unit: :kilometer).to_s)
  end

  private

  # Rounded like the distance on the card, so a rest below 0.5 km has no note
  def unrated_distance
    @unrated_distance ||= (@distance.to_f - @rated_distance).round
  end
end
