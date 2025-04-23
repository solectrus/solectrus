class Radio::Component < ViewComponent::Base
  def initialize(choices:, name:, url:)
    super
    @choices = choices
    @name = name
    @url = url
  end

  attr_reader :choices, :name, :url
end
