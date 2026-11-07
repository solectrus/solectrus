# A page whose timeframe defaults to the whole time, like the lists below the
# car page (see CarListPage) and the comparison of the heat pump. An invalid
# timeframe shows the whole time too. On a phone, the period of the whole
# time has a name of its own (see TimeframePagerItems).
#
# The controller gives `timeframe_page` (see TimeframePage::List).
module WholeTimeDefault
  extend ActiveSupport::Concern

  included do
    helper_method :timeframe, :pager_items
  end

  private

  def timeframe
    @timeframe ||= Timeframe.new(timeframe_param.presence || 'all')
  rescue ArgumentError
    @timeframe = Timeframe.new('all')
  end

  # The timeframe in the address of the page
  def timeframe_param = params[:timeframe]

  # The period of a phone, as the home pages have it
  def pager_items
    TimeframePagerItems.new(
      timeframe:,
      path: ->(timeframe) { timeframe_page.path(timeframe) },
      period_item: (timeframe.all? ? { name: timeframe_page.label_for_all } : {}),
    ).to_h
  end
end
