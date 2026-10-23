# A column of the overview of the car page, the charging or the driving, above
# its chart (see Car::Section and Cars::HomeController). The title links to
# the list of the column. A click on a figure loads its chart below, in the
# same column (see Car::ChartLink). The menu above the chart names it, so no
# figure stands out.
#
# The desktop has the head with a ring, the main number and its parts, and the
# further figures below it. A phone has no room for the ring, so it has a row
# of three tiles, and one chart for both columns below them.
class Car::OverviewBox::Component < ViewComponent::Base
  include Car::ChartLink

  # The soft box of the head and of a tile of the desktop, a step darker
  # with a hover
  BOX_CLASS = 'rounded-xl px-3 py-3 text-left bg-slate-100 hover:bg-slate-200 dark:bg-slate-700/30 dark:hover:bg-slate-700/50 focus-ring'.freeze
  private_constant :BOX_CLASS

  # A part of the main number with the color of its part of the ring, a CSS
  # color like "var(--color-sensor-pv)", and its whole share in percent
  Part = Data.define(:label, :value, :color, :percent)
  public_constant :Part

  # A part of the ring, in percent of the ring
  Segment = Data.define(:percent, :color)
  public_constant :Segment

  # The main number of the head, with the chart that it loads. `label` names
  # it for a screen reader.
  Head = Data.define(:sensor_name, :label, :value, :segments, :center, :center_label, :parts)
  public_constant :Head

  # A figure that loads its chart, with an optional bar of its span (see
  # Car::SpanBar::Component) or a note below the value. Its tooltip has the
  # `parts` of the value, like the cost of each source, and the paragraphs
  # of its `notes`, like how the value comes about.
  Figure = Data.define(:sensor_name, :label, :value, :bar, :note, :parts, :notes) do
    def initialize(bar: nil, note: nil, parts: [], notes: [], **) = super

    def tooltip? = parts.any? || notes.any?
  end
  public_constant :Figure

  # The link to the list of the column. `notes` name the open tasks of the
  # list, like the sessions to review. The link has an amber dot then, and a
  # screen reader reads the notes.
  List = Data.define(:label, :href, :icon, :notes) do
    def initialize(notes: [], **) = super
  end
  public_constant :List

  # `list` links the list of the column, if any. `figures` stand below the
  # head on the desktop, `tiles` in the row of a phone. A period without a
  # value, like a day without a drive, keeps them with 0 or a dash.
  def initialize(title:, list:, timeframe:, head:, figures: [], tiles: [])
    super()
    @title = title
    @list = list
    @timeframe = timeframe
    @head = head
    @figures = figures
    @tiles = tiles
  end

  attr_reader :title, :list, :timeframe, :head, :figures, :tiles

  # The box while its figures load: the title, an empty ring and a pulsing
  # bar in the place of each number. It has the layout of the box, so the
  # page keeps its height when the figures come (see the car page).
  def self.placeholder(title:, timeframe:)
    figure = Figure.new(sensor_name: nil, label: "\u00a0", value: skeleton('w-16'))
    head = Head.new(sensor_name: nil, label: nil, value: skeleton('w-40'), segments: [], center: nil, center_label: nil, parts: [])
    new(title:, list: nil, timeframe:, head:, figures: [figure], tiles: [figure] * 3)
  end

  # A gray bar in the height of the text around it, like the location row of
  # the live view while its name loads
  def self.skeleton(width)
    ActionController::Base.helpers.tag.span(class: ['inline-block align-middle h-[0.8em] rounded-full bg-slate-200 dark:bg-slate-700 animate-pulse motion-reduce:animate-none', width], aria: { hidden: true })
  end
  private_class_method :skeleton

  def heading_id = "overview-#{title.parameterize}"

  # A part of the ring below this share would be a hairline
  MIN_PERCENT = 0.3
  private_constant :MIN_PERCENT

  def segments = head.segments.select { it.percent >= MIN_PERCENT }

  # The ring as a conic gradient, gray without a part (see #ring_classes)
  def ring_style
    "background: #{ConicGradient.css(segments.map { [it.color, it.percent] })}" if segments.any?
  end

  def ring_classes
    class_names('relative flex shrink-0 items-center justify-center size-30 @min-[35rem]:size-28 rounded-full', 'bg-slate-200 dark:bg-slate-700' => segments.empty?)
  end

  # The tag and the options of a part that loads the chart of the sensor, or
  # of a plain block where the chart cannot draw the timeframe or the
  # selection. With `tooltip`, it has a tooltip (see
  # Car::OverviewBox::Tooltip::Component), below the part. A tap on a part
  # with a chart loads the chart, so its tooltip needs a long press.
  def figure_tag(sensor_name, tooltip: false, **, &)
    name = chart_sensor_name(sensor_name) if sensor_name
    data = tooltip ? { controller: 'tooltip', tooltip_touch_value: tooltip_touch(name) } : {}
    tag_name, attributes = chart_wrapper(name, link_class: 'cursor-pointer', data:, **)
    content_tag(tag_name, **attributes, &)
  end

  def tooltip_touch(sensor_name) = sensor_name ? 'long' : 'true'
end
