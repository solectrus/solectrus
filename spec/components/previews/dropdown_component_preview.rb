# @label Dropdown
class DropdownComponentPreview < ViewComponent::Preview
  def default
    render Dropdown::Component.new name: 'sensor-selector',
                                   items: [
                                     MenuItem::Component.new(
                                       name: 'This is the first item',
                                       sensor: 'f1',
                                       href: '#',
                                     ),
                                     MenuItem::Component.new(
                                       name: 'Second',
                                       sensor: 'f2',
                                       href: '#',
                                     ),
                                     MenuItem::Component.new(
                                       name: 'Third',
                                       sensor: 'f3',
                                       href: '#',
                                     ),
                                   ],
                                   selected: 'f1'
  end
end
