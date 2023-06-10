# @label Button
class ButtonComponentPreview < ViewComponent::Preview
  # @param title
  def primary(title: 'Click me')
    render Button::Component.new(title:, path: '#')
  end

  # Button with icon
  # @param icon select [sun, home, car, plug, bolt, chevron-left, chevron-right, plus, pencil,
  #                    trash, times, battery-empty, battery-quarter, battery-half, battery-three-quarters,
  #                    battery-full, arrow-right-to-bracket, arrow-right-from-bracket, cog]
  def icon(icon: 'bolt')
    render Button::Component.new(icon:, path: '#')
  end

  # @param title
  # @param icon select [sun, home, car, plug, bolt, chevron-left, chevron-right, plus, pencil,
  #                    trash, times, battery-empty, battery-quarter, battery-half, battery-three-quarters,
  #                    battery-full, arrow-right-to-bracket, arrow-right-from-bracket, cog]
  def icon_and_title(icon: 'bolt', title: 'Click me')
    render Button::Component.new(title:, icon:, path: '#')
  end

  # @param title
  def secondary(title: 'Edit', icon: 'pencil')
    render Button::Component.new(style: :secondary, title:, icon:, path: '#')
  end
end
