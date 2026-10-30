# A sample map for a visitor in the list of a car in the live view (see
# Car::LiveCard::Component), in place of the map of the admin. The location is
# personal data, so the map shows a made-up place in Stromberg, with a note that
# only the admin sees the real one, and the login.
class Car::LocationTeaser::Component < ViewComponent::Base
  # The market place of Stromberg in the Hunsrueck. "Strom" is German for electricity.
  LOCATION = [49.9456, 7.7747].freeze
  private_constant :LOCATION

  def initialize(css_class: nil)
    super()
    @css_class = css_class
  end

  attr_reader :css_class

  # The data of Car::Map::Component: the made-up location as its one place
  def map_cars = [{ places: [[*LOCATION, 1]] }]
end
