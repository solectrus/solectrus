class CardsController < ApplicationController
  def index; end

  private

  helper_method def calculator
    @calculator ||= Calculator.new((params[:timeframe] || 'current').to_sym)
  end
end
