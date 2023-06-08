# @label StatsNow
class StatsNowComponentPreview < ViewComponent::Preview
  def default
    render StatsNow::Component.new calculator:, field:
  end

  private

  def calculator
    Calculator::Now.new
  end

  def field
    'inverter_power'
  end
end
