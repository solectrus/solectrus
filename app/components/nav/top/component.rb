class Nav::Top::Component < ViewComponent::Base
  renders_many :primary_items, MenuItem::Component
  renders_many :secondary_items, MenuItem::Component
  renders_one :sub_nav

  def home_path
    root_path(
      sensor: 'inverter_power',
      timeframe: helpers.respond_to?(:timeframe) ? helpers.timeframe : 'now',
    )
  end

  def current_item
    primary_items.find(&:current)
  end
end
