class Nav::Top::Component < ViewComponent::Base
  renders_many :primary_items, MenuItem::Component
  renders_many :secondary_items, MenuItem::Component
  renders_one :sub_nav

  def root_item
    primary_items.first
  end

  def primary_items_without_root
    primary_items.drop(1)
  end

  def current_item
    primary_items.find(&:current) || secondary_items.find(&:current)
  end
end
