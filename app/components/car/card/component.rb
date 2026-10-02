# The frame of a card on the car page in a period: the block on top, the
# title below. Charging stands on the left and driving on the right, like
# the source and the usage of the power balance.
class Car::Card::Component < ViewComponent::Base
  def initialize(title:)
    super()
    @title = title
  end

  attr_reader :title
end
