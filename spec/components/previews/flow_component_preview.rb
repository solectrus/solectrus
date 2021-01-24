class FlowComponentPreview < ViewComponent::Preview
  def default
    render(Flow::Component.new(value: 4000, signal: false))
  end
end
