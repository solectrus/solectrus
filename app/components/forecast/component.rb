class Forecast::Component < ViewComponent::Base
  def initialize(interval: 5.minutes)
    super()
    @interval = interval
  end

  attr_reader :interval

  def show_outdoor_temp?
    Sensor::Config.exists?(:outdoor_temp_forecast)
  end
end
