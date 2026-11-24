# The note of an entry that an AI client wrote, until the admin saves it (see
# Origin): the robot of the lists (see OriginBadge::Component) with its text,
# in the color of secondary text. In the head of a modal it stands `inline`
# beside the title, in a form as a line of its own. An entry of the admin
# shows nothing.
class OriginNote::Component < ViewComponent::Base
  def initialize(record:, inline: false)
    super()
    @record = record
    @inline = inline
  end

  def render? = @record.origin_mcp?

  def call
    content = safe_join([icon('robot'), t('.text')])
    if @inline
      tag.span(content, class: 'ms-3 inline-flex items-center gap-1.5 align-middle text-sm font-normal text-muted')
    else
      tag.p(content, class: 'mb-4 flex items-center gap-2 text-sm text-muted')
    end
  end
end
