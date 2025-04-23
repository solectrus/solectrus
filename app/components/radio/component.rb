class Radio::Component < ViewComponent::Base
  def initialize(choices:, name:, frame_id:)
    super
    @choices = choices
    @name = name
    @frame_id = frame_id
  end

  attr_reader :choices, :name, :frame_id
end
