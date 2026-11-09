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

  # The route admits every sensor with a ranking, the permission aside
  def valid_params?
    return false unless sensor && calc
    return false if Sensor::Config.withheld?(sensor.name)

    # Check if sensor supports the requested aggregation
    sensor.allowed_aggregations.include?(calc.to_sym)
  end
end
