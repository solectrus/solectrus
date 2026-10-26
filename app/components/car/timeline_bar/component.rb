# A bar of the timeline of a day (see Car::DayTimeline::Component): a drive or
# a charge, its segments one above the other in the colors of their sources,
# each as high as its share. A piece of the line of the state of charge is a
# bar without segments, which shows only on a hover. A hover shows the
# tooltip of the bar, a tap on a phone too. A screen reader reads the tooltip
# of a drive or a charge as the label of its bar, and the label of the row of
# the line.
class Car::TimelineBar::Component < ViewComponent::Base
  # `bar` is a Car::TimelineBar::Bar
  def initialize(bar:)
    super()
    @bar = bar
  end

  attr_reader :bar

  # The place of the bar in its row, from its start to its end. A short bar
  # keeps the width of a mark, so it stays visible on a day of 24 hours.
  def style = "right: #{(100 - bar.to).round(3)}%; width: max(#{(bar.to - bar.from).round(3)}%, 0.25rem)"

  def attributes
    data = { controller: 'tooltip', tooltip_touch_value: 'true' }
    return { class: 'absolute inset-y-0 rounded-sm hover:bg-fill', style:, aria: { hidden: true }, data: } if bar.segments.empty?

    css_class = class_names(
      'absolute inset-y-0 flex flex-col-reverse gap-px overflow-hidden rounded-md',
      'rounded-l-none' => bar.ends.first == :square,
      'rounded-r-none' => bar.ends.last == :square,
      'timeline-bar-estimated' => bar.ends.last == :jagged,
      'timeline-bar-estimated-start' => bar.ends.first == :jagged,
    )
    { class: css_class, style:, role: 'img', aria: { label: bar.label }, data: }
  end

  def tooltip = Car::OverviewBox::Tooltip::Component.new(title: bar.title, lines: bar.lines, parts: bar.parts, notes: bar.notes)
end
