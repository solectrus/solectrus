# A column of the overview of the car page, the charging or the driving, above
# its chart (see Car::Section and Cars::HomeController). The title links to
# the list of the column. A click on a figure loads its chart below, in the
# same column (see Car::ChartLink). The menu above the chart names it, so no
# figure stands out.
#
# The figures stand in a row of three, in one box with a line between them.
# The desktop has a longer caption where it has room.
class Car::OverviewBox::Component < ViewComponent::Base
  include Car::ChartLink

  # A part of a value with the color of its part of the bar of a figure, a CSS
  # color like "var(--color-car-pv)", and its whole share in percent
  Part = Data.define(:label, :value, :color, :percent)
  public_constant :Part

  # A part of the bar of a figure, in percent of the bar
  Segment = Data.define(:percent, :color)
  public_constant :Segment

  # The swatch of a column without a color of its own, like a period without
  # charging, and while the figures load
  NEUTRAL = Segment.new(percent: 100, color: 'var(--color-fill-strong)')
  public_constant :NEUTRAL

  # A figure that loads its chart. `wide_label` is the caption of the desktop,
  # where it has room, `label` the one of a phone. It can have a bar of its
  # `segments`, like the sources of the charged energy. Its tooltip has the
  # `parts` of the value, like the cost of each source, the `bar` of a span
  # (see Car::SpanBar::Component), and the paragraphs of its `notes`, like how
  # the value comes about.
  Figure = Data.define(:sensor_name, :label, :wide_label, :value, :bar, :segments, :parts, :notes) do
    def initialize(wide_label: nil, bar: nil, segments: [], parts: [], notes: [], **) = super

    def tooltip? = parts.any? || notes.any?
  end
  public_constant :Figure

  # The link to the list of the column. `notes` name the open tasks of the
  # list, like the sessions to review. The link has an amber dot then, and a
  # screen reader reads the notes. A list with `sheet_href` opens in a sheet
  # on a phone (see SheetPage).
  List = Data.define(:label, :href, :notes, :sheet_href) do
    def initialize(notes: [], sheet_href: nil, **) = super
  end
  public_constant :List

  # The place of the figures of a period without a value, like a day without
  # a drive: a crossed out icon and a text, in the height of a figure
  Empty = Data.define(:icon, :text)
  public_constant :Empty

  # `list` links the list of the column, if any. A period without a value
  # shows `empty` in the place of the figures, which would be 0 and dashes.
  # `note` explains the column in an info icon beside its title, like the
  # window of the rates. `swatch` are the Segments of a small bar before the
  # title, in the colors of the bars of the column in the timeline of a day,
  # so the title tells what these bars show.
  def initialize(title:, list:, timeframe:, figures:, note: nil, swatch: [NEUTRAL], empty: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @title = title
    @list = list
    @timeframe = timeframe
    @figures = figures
    @note = note
    @swatch = swatch
    @empty = empty
  end

  attr_reader :title, :list, :timeframe, :figures, :note, :swatch, :empty

  # The box while its figures load: the title and a pulsing bar in the place
  # of each number. It has the layout of the box, so the page keeps its
  # height when the figures come (see the car page).
  def self.placeholder(title:, timeframe:)
    figure = Figure.new(sensor_name: nil, label: "\u00a0", value: skeleton('w-16'))
    new(title:, list: nil, timeframe:, figures: [figure] * 3)
  end

  # A gray bar in the height of the text around it, like the location row of
  # the live view while its name loads, or the savings while they load (see
  # Car::SavingsRow::Component)
  def self.skeleton(width)
    ActionController::Base.helpers.tag.span(class: ['inline-block align-middle h-[0.8em] rounded-full bg-fill-strong animate-pulse motion-reduce:animate-none', width], aria: { hidden: true })
  end

  def heading_id = "overview-#{title.parameterize}"

  # A part of the bar below this share would be a hairline
  MIN_PERCENT = 0.3
  private_constant :MIN_PERCENT

  def segments(figure) = figure.segments.select { it.percent >= MIN_PERCENT }

  # The tag and the options of a figure that loads the chart of the sensor,
  # or of a plain block where the chart cannot draw the timeframe or the
  # selection. With `tooltip`, it has a tooltip (see
  # Car::OverviewBox::Tooltip::Component), below the figure. A tap on a
  # figure with a chart loads the chart, so its tooltip needs a long press.
  def figure_tag(sensor_name, tooltip: false, **, &)
    name = chart_sensor_name(sensor_name) if sensor_name
    touch = name ? 'long' : 'true'
    data = tooltip ? { controller: 'tooltip', tooltip_touch_value: touch } : {}
    tag_name, attributes = chart_wrapper(name, link_class: 'cursor-pointer active:bg-fill-strong lg:hover:bg-fill-strong', data:, **)
    content_tag(tag_name, **attributes, &)
  end

  # A part of the box with a line before it
  def figure_classes(index)
    class_names(
      'flex min-w-0 flex-col gap-1 text-left focus-ring',
      'px-3 py-3 first:rounded-l-xl last:rounded-r-xl lg:px-5 lg:py-4',
      'border-l border-surface' => index.positive?,
    )
  end
end
