# The rows of one page of a list, from the block, and a Turbo frame that
# loads the next page when it comes into view. Each page has a frame of its
# own, with the id of the prefix and its number. A further page renders with
# `frame`, so it replaces the frame that loaded it.
class Ui::LazyRows::Component < ViewComponent::Base
  # The rows of the frames take the columns of the grid of the list
  CLASSES = 'col-span-full grid grid-cols-subgrid'.freeze
  private_constant :CLASSES

  # Whether the request asks for a further page of the list with the prefix
  def self.request?(request, prefix) = request.headers['Turbo-Frame']&.start_with?(prefix)

  def initialize(prefix:, pagy:, frame: false)
    super()
    @prefix = prefix
    @pagy = pagy
    @frame = frame
  end

  def call
    return rows unless @frame

    helpers.turbo_frame_tag(frame_id(@pagy.page), class: CLASSES) { rows }
  end

  private

  def rows = safe_join([content, next_page])

  def next_page
    return unless @pagy.next

    # A link in a row leaves the list, as on the first page, which lies in no
    # frame. Turbo keeps this frame and takes only the content of the
    # response, so the target goes here.
    helpers.turbo_frame_tag(frame_id(@pagy.next), src: @pagy.page_url(:next), loading: :lazy, target: '_top', class: CLASSES) do
      tag.div(helpers.icon('spinner', class: 'fa-spin'), class: 'col-span-full text-center py-4 text-gray-400')
    end
  end

  def frame_id(page) = "#{@prefix}#{page}"
end
