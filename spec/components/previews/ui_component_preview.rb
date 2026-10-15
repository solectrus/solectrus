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

  def grouped_list
    render Ui::GroupedList::Component.new(header: 'System') do |list|
      list.with_cell(name: 'Settings', icon: 'gear', href: '#')
      list.with_cell(name: 'Notifications', icon: 'message', href: '#', badge_count: 3)
      list.with_cell(name: 'About', icon: 'circle-info', href: 'https://solectrus.de')
      list.with_cell(name: 'Log out', icon: 'arrow-right-from-bracket', href: '#', destructive: true)
    end
  end

  def submit_button
    render Ui::SubmitButton::Component.new(delete_path: '#')
  end
end
