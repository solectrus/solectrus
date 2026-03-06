class RectBadge::Component < ViewComponent::Base
  def initialize(title:, css_class: nil)
    super()
    @title = title
    @css_class = css_class
  end

  attr_reader :title, :css_class
end
