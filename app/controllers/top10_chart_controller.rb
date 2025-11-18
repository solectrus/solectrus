class Top10ChartController < ApplicationController
  include ParamsHandling

  def index
    # Validate parameters before rendering
    unless valid_params?
      head :not_found
      return
    end

    render formats: :turbo_stream
  end

  private

  def valid_params?
    return false unless sensor && calc

    # Check if sensor supports the requested aggregation
    sensor.allowed_aggregations.include?(calc.to_sym)
  end
end
