# @label Button
# @logical_path general
class ButtonComponentPreview < ViewComponent::Preview
  # @!group Overview

  # @param label
  def primary(label: 'Click me')
    render Ui::Button::Component.new(label:, href: '#')
  end

  # Button with icon
  # @param icon select [sun, home, car, plug, bolt, chevron-left, chevron-right, plus, pencil,
  #                    trash, xmark, battery-empty, battery-quarter, battery-half, battery-three-quarters,
  #                    battery-full, arrow-right-to-bracket, arrow-right-from-bracket, gear]
  def icon(icon: 'bolt')
    render Ui::Button::Component.new(icon:, href: '#')
  end

  # @param label
  # @param icon select [sun, home, car, plug, bolt, chevron-left, chevron-right, plus, pencil,
  #                    trash, xmark, battery-empty, battery-quarter, battery-half, battery-three-quarters,
  #                    battery-full, arrow-right-to-bracket, arrow-right-from-bracket, gear]
  def icon_and_label(icon: 'bolt', label: 'Click me')
    render Ui::Button::Component.new(label:, icon:, href: '#')
  end

  # @param label
  def secondary(label: 'Edit', icon: 'pencil')
    render Ui::Button::Component.new(style: :secondary, label:, icon:, href: '#')
  end

  # @!endgroup
end
