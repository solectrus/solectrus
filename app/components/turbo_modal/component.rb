class TurboModal::Component < ViewComponent::Base
  # This component is based on:
  # https://www.bearer.com/blog/how-to-build-modals-with-hotwire-turbo-frames-stimulusjs
  # and
  # https://bhserna.com/remote-modals-with-rails-hotwire-and-bootstrap.html

  include Turbo::FramesHelper

  def initialize(title:)
    super()
    @title = title
  end
end
