class Forecast::Component < ViewComponent::Base
  def initialize(days:)
    super()
    @days = days
  end

  attr_reader :days

  def show_outdoor_temp?
    Sensor::Config.exists?(:outdoor_temp_forecast)
  end
end
