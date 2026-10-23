# The mark of a charging session to review in a row of the list, like a
# session that is not assigned or a proposal: a question mark on a badge in
# the size of a car badge (see Car::Badge::Component), in the amber of the
# sessions to review. Its tooltip and a screen reader name the task.
class ChargingSession::ReviewBadge::Component < ViewComponent::Base
  def initialize(label:)
    super()
    @label = label
  end

  attr_reader :label

  # The icon stands in a box of the height of a line, so the badge has the
  # height of a car badge with its text. A question mark as tall as the
  # text would look larger than the text beside it.
  def call
    tag.span(
      tag.span(icon('question', class: 'text-[0.75em]'), class: 'inline-flex items-center h-[1lh]'),
      class: 'inline-flex shrink-0 rounded-full px-2.5 py-0.5 text-xs sm:text-sm bg-attention text-on-attention',
      role: 'img',
      title: label,
      aria: { label: },
      data: { controller: 'tooltip' },
    )
  end
end
