class HomeController < ApplicationController
  def index; end

  private

  helper_method def calculator
    @calculator ||= Calculator.new(:last24h)
  end
end
