# The title of a section of a card on the car page, centered between two
# lines, like the title above the charging sessions
class Car::SectionTitle::Component < ViewComponent::Base
  def initialize(title:)
    super()
    @title = title
  end

  attr_reader :title
end
