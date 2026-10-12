# A list of the car page, like the charging sessions or the visits. Only the
# admin sees it (see CarPageGate), and it has a timeframe that defaults to the whole time.
module CarListPage
  extend ActiveSupport::Concern
  include CarPageGate
  include TimeframeSelectModal

  included do
    helper_method :timeframe
  end

  private

  # A closed car page sends its list to the start page, or to the car page
  # with its upsell
  def car_page_closed
    redirect_to(Sensor::HomePage.available?(:cars) ? cars_home_path : root_path)
  end

  def timeframe
    @timeframe ||= Timeframe.new(params[:timeframe].presence || 'all')
  rescue ArgumentError
    @timeframe = Timeframe.new('all')
  end
end
