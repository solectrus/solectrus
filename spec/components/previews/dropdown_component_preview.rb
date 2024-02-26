# @label Dropdown
class DropdownComponentPreview < ViewComponent::Preview
  def default
    render Dropdown::Component.new items: [
                                     {
                                       name: 'This is the first item',
                                       sensor: 'f1',
                                       href: '#',
                                     },
                                     {
                                       name: 'Second',
                                       sensor: 'f2',
                                       href: '#',
                                     },
                                     { name: 'Third', sensor: 'f3', href: '#' },
                                   ],
                                   selected: 'f1'
  end
end
