# A bar of a lane of the timeline of a day (see Car::TimelineBar::Component),
# from its start to its end in percent of the day. `segments` are [[CSS
# color, share], ...] one above the other, none for a piece of the line of
# the state of charge. `pauses` are [[left, width], ...] in percent of the
# bar, the times in which the car stayed plugged in but did not charge.
# `ends` are the looks of its start and of its end: :round, :square where it
# touches another bar of its row, or :jagged where the start or the end is
# an estimate.
#
# Its tooltip has a title, `lines` below it, like the town and the street of
# an address, `parts` and `notes`. A drive without a known start is a mark
# at its end. A bar with `href` opens its entry, on a phone at `sheet_href`.
Car::TimelineBar::Bar = Data.define(:from, :to, :segments, :pauses, :ends, :title, :lines, :parts, :notes, :href, :sheet_href) do
  def initialize(segments: [], pauses: [], ends: %i[round round], parts: [], notes: [], href: nil, sheet_href: nil, **) = super # rubocop:disable Metrics/ParameterLists

  # The text of the tooltip for a screen reader
  def label = [title, *lines, *parts.map { [it.label, it.value.presence, ("#{it.percent} %" if it.percent)].compact.join(' ') }, *notes].join(', ')
end
