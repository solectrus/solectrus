class FinanceBadge::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end
  attr_reader :data, :timeframe

  def missing_price?(sensor_name)
    data.public_send(sensor_name).nil?
  end
end
