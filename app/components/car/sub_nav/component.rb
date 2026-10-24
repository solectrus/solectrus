# The header of a page below the car page: the lists of the charging sessions
# and of the places. The views render it into `content_for :sub_nav`.
#
# The desktop starts with the way back, and then the lists as pills (`tabs`),
# or the title of the page. At the right stand the button for a new entry
# (`add`), the select of the car and the timeframe. A phone starts with the
# timeframe in one row, at the very top as on the home pages. Below it stands
# the title bar with the way back (`back`, see Ui::TitleBar::Component), and
# at the right the select of the car as a round button and the button for a
# new entry.
class Car::SubNav::Component < ViewComponent::Base
  # The timeframe of the desktop, for example in its frame
  renders_one :timeframe

  # `back` takes the options of the way back of Ui::TitleBar::Component.
  # `desktop_back` is the way back of the desktop, which has no page More.
  # `segments` are the items of the timeframe of a phone (see
  # TimeframeSegmentItems). `add` is a hash with :href and :label, or nil.
  # `car_select` builds the select of the car with the options of its place,
  # or is nil.
  def initialize(title:, back:, segments:, desktop_back: back[:back_href], tabs: [], add: nil, car_select: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @title = title
    @back = back
    @segments = segments
    @desktop_back = desktop_back
    @tabs = tabs
    @add = add
    @car_select = car_select
  end

  attr_reader :title, :back, :segments, :desktop_back, :tabs, :add

  def car_select? = !@car_select.nil?

  def header_car_select = render(@car_select.call)

  # The pill below the timeframe of a phone or a tablet, which the car page has
  PILL_SELECT = { button_class: 'bg-white/20 text-white ring-1 ring-inset ring-white/35 font-semibold dark:bg-white/10', mobile_shape: 'rounded-full px-3.5' }.freeze
  public_constant :PILL_SELECT

  # The round button in the title bar of a phone, with the icon of the car
  TITLE_BAR_SELECT = { button_class: '', mobile_shape: 'ui-title-bar-action', mobile_icon: true }.freeze
  private_constant :TITLE_BAR_SELECT

  def title_bar_car_select = render(@car_select.call(**TITLE_BAR_SELECT))
end
