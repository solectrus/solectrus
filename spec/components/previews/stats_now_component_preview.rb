# @label StatsNow
class StatsNowComponentPreview < ViewComponent::Preview
  def default
    render StatsNow::Component.new calculator:
  end

  private

  def calculator
    Calculator::Now.new
  end
end
