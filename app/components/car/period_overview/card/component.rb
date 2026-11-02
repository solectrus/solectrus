# A card of the overview of a period of the car page (see
# Car::PeriodOverview::Component), the charging or the driving: its total on
# top, like the charged energy, and below it a row of cells with what belongs
# to it, like its cost and the link to its list. The card of the charging has
# a bar of its sources between them, each as wide as its energy. Each part
# loads its chart or opens its page (see Car::FigureTag), and its tooltip
# says more.
#
# The card of the driving has its total as its `lead`: large, in the height
# that the bar of the sources takes in the card of the charging, so both
# cards have one height.
class Car::PeriodOverview::Card::Component < ViewComponent::Base
  include Car::FigureTag

  # A source of the bar: a Car::Figure with its value, its icon and its
  # tooltip, the `weight` of its width and its color classes
  Segment = Data.define(:figure, :weight, :css)
  public_constant :Segment

  # A cell of the row: a Car::Figure, with a `label` below its value where
  # the card does not say what it is, like the consumption per 100 km
  Cell = Data.define(:figure, :label) do
    def initialize(label: nil, **) = super
  end
  public_constant :Cell

  # The link to the list of the card. `notes` name the open tasks of the
  # list, like the sessions to review. The link has an amber dot then, and a
  # screen reader reads the notes. A list with `sheet_href` opens in a sheet
  # on a phone (see SheetPage).
  List = Data.define(:label, :href, :notes, :sheet_href) do
    def initialize(notes: [], sheet_href: nil, **) = super
  end
  public_constant :List

  # A period without a value, like a day without charging: a crossed out
  # icon and a text
  Empty = Data.define(:icon, :text)
  public_constant :Empty

  # `title` names the card for a screen reader, like "Charging". `main` is
  # the Car::Figure of the total, with `caption` after its value, like
  # "charged". `cells` are Cells and at most one List, the link to the list
  # of the card. `empty` is an Empty for a period without a value, like a
  # day without a drive. The card then shows it alone, or with a link to a
  # list in the place of the `segments`, like sessions that the numbers leave
  # out.
  def initialize(title:, timeframe:, main:, cells:, css_class:, caption: nil, lead: false, segments: nil, empty: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @title = title
    @timeframe = timeframe
    @main = main
    @cells = cells
    @css_class = css_class
    @caption = caption
    @lead = lead
    @segments = segments
    @empty = empty
  end

  attr_reader :title, :timeframe, :main, :cells, :css_class, :caption, :segments, :empty

  def lead? = @lead

  # The sources with a share of the whole. A source of 0 would be a line.
  def shown_segments = segments.to_a.select { it.weight.positive? }

  # The bar of the sources, or its place without charging
  def bar? = !segments.nil?

  # Whether the card shows `empty` alone
  def blank? = empty.present? && cells.none? { list?(it) }

  def list?(cell) = cell.is_a?(List)

  # A part of the card, which brightens on hover
  def link_class = 'active:bg-white/10 lg:hover:bg-white/10'
end
