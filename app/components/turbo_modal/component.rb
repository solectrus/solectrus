class TurboModal::Component < ViewComponent::Base
  # This component is based on:
  # https://www.bearer.com/blog/how-to-build-modals-with-hotwire-turbo-frames-stimulusjs
  # and
  # https://bhserna.com/remote-modals-with-rails-hotwire-and-bootstrap.html

  renders_one :title

  include Turbo::FramesHelper

  def initialize(title: nil, narrow: false, wide: false)
    super()
    @title = title
    @narrow = narrow
    @wide = wide
  end

  # Width on desktop. Forms need the room, running text does not: a narrow
  # panel keeps a line below ~65 characters. A wide panel lets a long form
  # put its fields side by side, so it fits the height of a laptop screen.
  def width_class
    if @narrow
      'md:max-w-xl'
    elsif @wide
      'md:max-w-3xl lg:max-w-5xl'
    else
      'md:max-w-3xl'
    end
  end
end
