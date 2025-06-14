class InsightsTile::Component < ViewComponent::Base
  renders_one :title
  renders_one :body
  renders_one :footer

  def initialize(url: nil, class: nil, incomplete: false)
    super
    @url = url
    @css_class = binding.local_variable_get(:class)
    @incomplete = incomplete
  end

  attr_reader :url, :css_class, :incomplete
end
