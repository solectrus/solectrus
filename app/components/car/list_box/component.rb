# A list below the car page, of the charging sessions or the places: a head
# with the switch of the lists (see Ui::SegmentedControl::Component), its
# filter, the sums of the list and the button of its map, and the list as the content. The
# desktop has it on the white page without a card of its own. A phone has the
# head on the gray page, and the list in the cards of a grouped list.
#
# The map is a button with its name on the desktop, and an icon at the end of
# the sums on a phone. It opens the map over the list, which fills the
# window (see Car::MapOverlay::Component).
class Car::ListBox::Component < ViewComponent::Base
  # `segments` are the items of the switch, empty for one list. `totals_note`
  # explains the sums in their tooltip, like a cost that is a minimum.
  # `map_path` opens the map, or is nil. `map_label` names the map for the
  # icon of a phone.
  def initialize(label:, segments: [], totals: nil, totals_note: nil, map_path: nil, map_label: nil)
    super()
    @label = label
    @segments = segments
    @totals = totals
    @totals_note = totals_note
    @map_path = map_path
    @map_label = map_label
  end

  attr_reader :label, :segments, :totals, :totals_note, :map_path, :map_label

  # A separated part of the card below its head, like a row above the list
  renders_many :notes

  # A filter of the list, like the pill of a place (see Ui::FilterBar::Pill).
  # On a phone the switch, the filter and the sums each take a line of their
  # own, so a switch to a list without a filter moves none of them.
  renders_one :filter

  # A small switch beside the sums, like the one of the sessions to review
  renders_one :switch

  def head? = segments.any? || totals.present? || map_path.present? || filter? || switch?

  def map_frame = Car::MapOverlay::Component::FRAME_ID

  # The sums with each number in bold, and the units and the words in the
  # normal weight, like 4 sessions and 55.6 kWh
  def totals_html
    ERB::Util.html_escape(totals).to_str.gsub(NUMBER) { tag.span(it, class: 'font-semibold text-fg') }.html_safe # rubocop:disable Rails/OutputSafety
  end

  # A number with its separators, like 1.877,83
  NUMBER = /\d[\d.,]*\d|\d/
  private_constant :NUMBER
end
