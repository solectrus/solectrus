# A row of a list in the manner of iOS: the label on the left, the value from
# the block on the right, and an optional gray detail below the label. A note
# stands in parentheses beside the label, like a period or a share. A row
# with a URL leads to that page, a row with an action (Stimulus) is a button.
# Both show a chevron.
class Insights::Row::Component < ViewComponent::Base
  renders_one :swatch

  # Up to this length, label and note fit beside a value on any phone
  SHORT_LABEL_LENGTH = 20
  private_constant :SHORT_LABEL_LENGTH

  def initialize(label:, note: nil, detail: nil, url: nil, action: nil)
    super()
    @label = label
    @note = note
    @detail = detail
    @url = url
    @action = action
  end

  attr_reader :label, :note, :detail, :url, :action

  def container_tag
    if url
      [:a, { href: url, class: 'insights-row insights-row-link' }]
    elsif action
      [:button, { type: 'button', class: 'insights-row insights-row-link w-full text-left cursor-pointer', data: { action: } }]
    else
      [:div, { class: 'insights-row' }]
    end
  end

  def chevron?
    url || action
  end

  # The stylesheet sets the parentheses. A long note moves to a line of its
  # own where the row is narrow, a short one like "(2024)" stays beside the
  # label.
  def note_class
    long = "#{label} (#{note})".length > SHORT_LABEL_LENGTH
    ['insights-row-label-note', ('insights-row-label-note-long' if long)]
  end
end
