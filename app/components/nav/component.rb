class Nav::Component < ViewComponent::Base
  def initialize(items:)
    super
    @items = items
  end

  attr_reader :items
end
