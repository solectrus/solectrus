class DemoLink::Component < ViewComponent::Base
  def initialize(url:)
    super
    @url = url
  end

  attr_reader :url
end
