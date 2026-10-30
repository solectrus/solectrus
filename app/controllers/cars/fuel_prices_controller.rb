# The prices of the fuel of the comparison with a combustion car in a modal
# (see Car::FuelPriceChart::Component). The price range on the page of the
# comparison links to it. It has the timeframe and the car of the page, and
# nothing without a comparison (see Cars::SavingsController).
class Cars::FuelPricesController < ApplicationController
  include Cars::PageGate

  # The prices are public data, like the page of the comparison
  skip_before_action :admin_required!
  before_action :load_comparison
  helper_method :timeframe

  def index
  end

  private

  def load_comparison
    @comparison = Car::Report.new(timeframe, CarSelection.new(params[:car], timeframe:).cars).comparison
    head(:not_found) unless @comparison&.possible?
  end

  # An invalid timeframe is the whole time, like on the page (see
  # CarListPage#timeframe)
  def timeframe
    @timeframe ||= Car::Comparison.timeframe(Timeframe.new(params[:timeframe].presence || 'all'))
  rescue ArgumentError
    @timeframe = Car::Comparison.timeframe(Timeframe.new('all'))
  end
end
