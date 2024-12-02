class House::ChartsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    render formats: :turbo_stream
  end

  helper_method def chart_sensors
    %i[house_power] + (1..10).map { |i| format('custom_%02d_power', i).to_sym }
  end
end
