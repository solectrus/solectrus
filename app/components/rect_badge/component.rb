class RectBadge::Component < ViewComponent::Base
  def initialize(title:)
    super()
    @title = title
  end

  attr_reader :title
end
