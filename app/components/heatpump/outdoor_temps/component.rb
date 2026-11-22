# The two outdoor temperatures of a period in the tile of the heat pump
# page: the average of all days, and beside it the temperature while
# heating, each day counted by its heat (see Sensor::Definitions::Dsl#trend).
# A line parts them, and a tooltip of its own explains each.
class Heatpump::OutdoorTemps::Component < ViewComponent::Base
  def initialize(average:, heating:)
    super()
    @average = average
    @heating = heating
  end

  attr_reader :average, :heating

  def sensor = Sensor::Registry[:outdoor_temp]
end
