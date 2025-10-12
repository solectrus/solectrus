class Heatpump::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to heatpump_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    SummarizerJob.perform_for_timeframe(timeframe)
  end

  def data_now
    data =
      Sensor::Query::Influx::Latest.new(
        %i[
          heatpump_status
          heatpump_power
          heatpump_heating_power
          heatpump_tank_temp
          heatpump_cop
          outdoor_temp
          heatpump_power_env
          heatpump_power_pv
          heatpump_power_grid
        ],
      ).call
    HeatpumpBalance.new(data)
  end

  def data_range
    data =
      Sensor::Query::Sql
        .new do |q|
          q.sum :heatpump_power, :sum
          q.sum :heatpump_power_grid, :sum
          q.sum :heatpump_power_pv, :sum
          q.sum :heatpump_power_env, :sum
          q.sum :heatpump_heating_power, :sum
          q.avg :heatpump_tank_temp, :avg
          q.avg :heatpump_cop, :avg
          q.sum :heatpump_costs_pv, :sum
          q.sum :heatpump_costs_grid, :sum
          q.avg :outdoor_temp, :avg

          q.timeframe timeframe
        end
        .call
    HeatpumpBalance.new(data)
  end
end
