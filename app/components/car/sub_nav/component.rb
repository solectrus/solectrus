# The header of a page below the car page: the lists of the charging sessions
# and of the places. The views render it into `content_for :sub_nav`.
#
# The desktop starts with the way back, and then the lists as pills (`tabs`),
# or the title of the page. At the right stand the button for a new entry
# (`add`), the select of the car and the timeframe. A phone has the title bar
# with the way back (`back`, see Ui::TitleBar::Component) and the button for
# a new entry. Its period and the cars as chips stand at the top of the
# content, as on the car page (see Timeframe::Pager::Component).
class Car::SubNav::Component < ViewComponent::Base
  # The timeframe of the desktop, for example in its frame
  renders_one :timeframe

  # `back` takes the options of the way back of Ui::TitleBar::Component.
  # `desktop_back` is the way back of the desktop, which has no page More.
  # `add` is a hash with :href and :label, or nil. `car_select` is the select
  # of the car of the desktop (see Car::Select::Component), or nil.
  def initialize(title:, back:, desktop_back: back[:back_href], tabs: [], add: nil, car_select: nil)
    super()
    @title = title
    @back = back
    @desktop_back = desktop_back
    @tabs = tabs
    @add = add
    @car_select = car_select
  end

  attr_reader :title, :back, :desktop_back, :tabs, :add

  def car_select? = !@car_select.nil?

  def header_car_select = render(@car_select)
end
