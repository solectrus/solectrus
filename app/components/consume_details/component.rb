class ConsumeDetails::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  attr_accessor :data
end
