class DemoLink::Component < ViewComponent::Base
  def initialize(feature:, url: nil)
    super
    @url = url
    @feature = feature
  end

  attr_reader :url, :feature
end
