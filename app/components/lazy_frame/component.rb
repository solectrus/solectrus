# A Turbo frame that fills itself from a separate request, showing a centered
# spinner until the response arrives. Wherever the page shell wants to be on
# screen before some slower part of it is ready, this keeps the frame and its
# placeholder together instead of repeating the spinner markup at every frame.
#
# Passing a block renders that instead of the spinner - for the case where the
# contents happen to be at hand already (then there is nothing to fetch, and
# src is simply nil).
class LazyFrame::Component < ViewComponent::Base
  # Everything but the id and the src is passed through to the frame tag, so
  # callers keep their own layout classes, target and data attributes.
  def initialize(id:, src: nil, **options)
    super()
    @id = id
    @src = src
    @options = options
  end

  attr_reader :id, :src, :options
end
