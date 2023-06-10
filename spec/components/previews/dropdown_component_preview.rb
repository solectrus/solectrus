# @label Dropdown
class DropdownComponentPreview < ViewComponent::Preview
  def default
    render Dropdown::Component.new items: [
                                     {
                                       name: 'This is the first item',
                                       field: 'f1',
                                       href: '#',
                                     },
                                     { name: 'Second', field: 'f2', href: '#' },
                                     { name: 'Third', field: 'f3', href: '#' },
                                   ],
                                   selected: 'f1'
  end
end
