# The switch between the charging card and the driving card on a phone,
# where the two cards do not fit side by side (see car_cards_controller.ts).
# `card` is the card the page shows.
class Car::CardToggle::Component < ViewComponent::Base
  CARDS = %w[charging driving].freeze
  public_constant :CARDS

  # The cookie of the choice. Without it, the page shows the charging card.
  COOKIE = :car_card
  public_constant :COOKIE

  # The card of the cookie
  def self.card(cookies) = cookies[COOKIE].presence_in(CARDS) || CARDS.first

  def initialize(card:)
    super()
    @card = card
  end

  attr_reader :card
end
