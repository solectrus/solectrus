# @label DashboardNow Component
class DashboardNowComponentPreview < ViewComponent::Preview
  def default
    render DashboardNow::Component.new calculator:
  end

  private

  def calculator
    Calculator::Now.new
  end
end
