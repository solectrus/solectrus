class House::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to house_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now? || timeframe.hours?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Sensor::Summarizer.call(timeframe)
  end

  def data_now
    data =
      Sensor::Query::Latest.new(
        %i[
          house_power
          house_power_without_custom
          house_power_grid
          grid_import_power
        ] +
          Sensor::Config
            .house_power_included_custom_sensors
            .flat_map { |sensor| [sensor.name, :"#{sensor.name}_grid"] },
      ).call
    HouseBalance.new(data)
  end

  def data_range
    data =
      Sensor::Query::Total
        .new(timeframe) do |q|
          q.sum :house_power, :sum
          q.sum :house_power_grid, :sum
          q.sum :house_power_without_custom, :sum

          Sensor::Config.house_power_included_custom_sensors.each do |sensor|
            q.sum sensor.name, :sum
            q.sum :"#{sensor.name}_grid", :sum
          end
          q.sum :custom_power_total, :sum

          q.sum :house_costs, :sum
          q.sum :house_costs_grid, :sum
          q.sum :house_costs_pv, :sum
          Sensor::Config.house_power_included_custom_sensors.each do |sensor|
            sensor_base = sensor.name.to_s.gsub('_power', '')
            q.sum :"#{sensor_base}_costs", :sum
            q.sum :"custom_costs_#{sensor_base.sub('custom_', '')}_grid", :sum
            q.sum :"custom_costs_#{sensor_base.sub('custom_', '')}_pv", :sum
          end
          q.sum :house_without_custom_costs, :sum
        end
        .call

    HouseBalance.new(data)
  end
end
