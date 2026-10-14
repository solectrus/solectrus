# @label UI building blocks
# @logical_path ui
class UiComponentPreview < ViewComponent::Preview
  def nav_list
    render Ui::NavList::Component.new(
      label: 'Settings',
      items: [
        { name: 'General', href: '#', icon: 'gear' },
        { name: 'Sensors', href: '#', icon: 'sliders' },
        { name: 'Payments', href: '#', icon: 'piggy-bank' },
      ],
    )
  end

  def submit_button
    render Ui::SubmitButton::Component.new(delete_path: '#')
  end
end
