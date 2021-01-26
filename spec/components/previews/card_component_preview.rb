class CardComponentPreview < ViewComponent::Preview
  def default
    render_with_template
  end

  def signal_false
    render_with_template
  end

  def signal_true
    render_with_template
  end

  def signal_value
    render_with_template
  end
end
