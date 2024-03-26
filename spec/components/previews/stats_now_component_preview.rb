# @label StatsNow
class StatsNowComponentPreview < ViewComponent::Preview
  def default
    render StatsNow::Component.new calculator:, sensor:
  end

  private

  def calculator
    Calculator::Now.new
  end

  def sensor
    'inverter_power'
  end
end
