class DemoLink::Component < ViewComponent::Base
  def initialize(url:, feature:)
    super
    @url = url
    @feature = feature
  end

  attr_reader :url, :feature
end
