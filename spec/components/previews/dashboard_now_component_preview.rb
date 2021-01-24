class DashboardNowComponentPreview < ViewComponent::Preview
  def default
    render(DashboardNow::Component.new(calculator: Calculator::Now.new))
  end
end
