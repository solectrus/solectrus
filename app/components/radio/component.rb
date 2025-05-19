class Radio::Component < ViewComponent::Base
  def initialize(choices:, name:, frame_id:, url:)
    super
    @choices = choices
    @name = name
    @frame_id = frame_id
    @url = url
  end

  attr_reader :choices, :name, :frame_id, :url
end
