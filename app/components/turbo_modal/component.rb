class TurboModal::Component < ViewComponent::Base
  # This component is based on:
  # https://www.bearer.com/blog/how-to-build-modals-with-hotwire-turbo-frames-stimulusjs
  # and
  # https://bhserna.com/remote-modals-with-rails-hotwire-and-bootstrap.html

  renders_one :title

  include Turbo::FramesHelper

  def initialize(title: nil, narrow: false)
    super()
    @title = title
    @narrow = narrow
  end

  # Width on desktop. Forms need the room, running text does not: a narrow
  # panel keeps a line below ~65 characters.
  def width_class
    @narrow ? 'md:max-w-xl' : 'md:max-w-3xl'
  end
end
