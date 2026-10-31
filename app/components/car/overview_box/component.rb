# A column of the overview of the car page, the charging or the driving, above
# its chart (see Car::Section and Cars::HomeController). The title links to
# the list of the column. A click on a figure loads its chart below, in the
# same column (see Car::ChartLink). The menu above the chart names it, so no
# figure stands out.
#
# The box has one figure that leads, large and without a caption, because
# the title of the column says what it counts. The other figures stand
# beside it, without a caption: their tooltips name them. Below them, a bar
# shows the parts of a whole, like the sources of the charged energy (see
# Car::ShareBar::Component).
class Car::OverviewBox::Component < ViewComponent::Base
  include Car::ChartLink

  # A part of a value with the color of its part of a bar, a CSS color like
  # "var(--color-car-pv)", and its whole share in percent
  Part = Data.define(:label, :value, :color, :percent) do
    def initialize(color: nil, percent: nil, **) = super
  end
  public_constant :Part

  # A figure that loads its chart, or with `href` opens a page, like the
  # comparison with a combustion car. The tooltip names the figure with its
  # `title`, which a screen reader reads beside the value, and says in its
  # `description` what the value counts. It has the `parts` of the value, like the cost of each source,
  # the `bar` of a span (see Car::SpanBar::Component), and the paragraphs of
  # its `notes`, like how the value comes about.
  Figure = Data.define(:sensor_name, :value, :href, :title, :description, :bar, :parts, :notes) do
    def initialize(href: nil, title: nil, description: nil, bar: nil, parts: [], notes: [], **) = super # rubocop:disable Metrics/ParameterLists

    def tooltip? = title.present? || parts.any? || notes.any?
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
  # a drive: a crossed out icon and a text, in the height of the figures
  Empty = Data.define(:icon, :text)
  public_constant :Empty

  # `list` links the list of the column, if any. The first of the `figures`
  # leads. `bar` is a Figure whose value is a Car::ShareBar::Component. A
  # period without a value shows `empty` in the place of the figures, which
  # would be 0 and dashes. It keeps the place of the bar, if any. `note`
  # explains the column in an info icon beside its title, like the window of
  # the rates.
  def initialize(title:, list:, timeframe:, figures:, bar: nil, note: nil, empty: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @title = title
    @list = list
    @timeframe = timeframe
    @figures = figures
    @bar = bar
    @note = note
    @empty = empty
  end

  attr_reader :title, :list, :timeframe, :figures, :bar, :note, :empty

  # The box while its figures load: the title and a pulsing bar in the place
  # of each number, and with `bar` a pulsing track. It has the layout of the
  # box, so the page keeps its height when the figures come (see the car
  # page).
  def self.placeholder(title:, timeframe:, bar: false)
    lead = Figure.new(sensor_name: nil, value: skeleton('w-24'))
    side = Figure.new(sensor_name: nil, value: skeleton('w-14'))
    track = Figure.new(sensor_name: nil, value: Car::ShareBar::Component.new(segments: [], pulse: true)) if bar
    new(title:, list: nil, timeframe:, figures: [lead, side, side], bar: track)
  end

  # A gray bar in the height of the text around it
  def self.skeleton(width)
    ActionController::Base.helpers.tag.span(class: ['inline-block align-middle h-[0.8em] rounded-full bg-fill-strong animate-pulse motion-reduce:animate-none', width], aria: { hidden: true })
  end
  private_class_method :skeleton

  def heading_id = "overview-#{title.parameterize}"

  def lead = figures.first

  def side_figures = figures.drop(1)

  # The tag and the options of a figure that loads the chart of its sensor
  # or opens its page, or of a plain block where the chart cannot draw the
  # timeframe or the selection. A figure with a tooltip has it below (see
  # Car::OverviewBox::Tooltip::Component). A tap on a link opens it, so its
  # tooltip needs a long press. `link_class` applies to a link alone, and
  # `placement` places the tooltip, like beside the lead.
  def figure_tag(figure, link_class: 'cursor-pointer active:bg-fill-strong lg:hover:bg-fill-strong', placement: nil, **options, &)
    name = figure.sensor_name && chart_sensor_name(figure.sensor_name)
    touch = figure.href || name ? 'long' : 'true'
    data = figure.tooltip? ? { controller: 'tooltip', tooltip_touch_value: touch, tooltip_placement_value: placement }.compact : {}
    tag_name, attributes =
      if figure.href
        [:a, { **options, href: figure.href, class: [*options[:class], link_class], data: }]
      else
        chart_wrapper(name, link_class:, data:, **options)
      end
    content_tag(tag_name, **attributes, &)
  end

  def tooltip(figure)
    Car::OverviewBox::Tooltip::Component.new(title: figure.title, lines: [figure.description].compact, parts: figure.parts, notes: figure.notes, bar: figure.bar)
  end
end
