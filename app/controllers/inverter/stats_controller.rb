class Inverter::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to inverter_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Sensor::Summarizer.call(timeframe)
  end

  def data_now
    sensor_names =
      %i[inverter_power_difference system_status] +
        Sensor::Config.inverter_sensors.map(&:name)

    data = Sensor::Query::Influx::Latest.new(sensor_names).call
    InverterBalance.new(data)
  end

  def data_range
    data =
      Sensor::Query::Sql
        .new do |q|
          Sensor::Config.inverter_sensors.each do |sensor|
            q.sum sensor.name, :sum
          end
          q.sum :inverter_power_difference, :sum

          q.timeframe timeframe
        end
        .call
    InverterBalance.new(data)
  end
end
