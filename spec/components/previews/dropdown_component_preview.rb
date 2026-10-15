# @label Dropdown
# @logical_path navigation
class DropdownComponentPreview < ViewComponent::Preview
  def default
    render Ui::Dropdown::Component.new(
      name: 'sensor-selector',
      items: [
        Ui::MenuItem::Component.new(name: 'This is the first item', id: 'f1', href: '#'),
        Ui::MenuItem::Component.new(name: 'Second', id: 'f2', href: '#'),
        Ui::MenuItem::Component.new(name: 'Third', id: 'f3', href: '#'),
      ],
      selected: 'f1',
    )
  end
end
