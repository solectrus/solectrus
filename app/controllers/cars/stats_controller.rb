class Cars::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include SponsoredFrame
  include CarSelectable

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to cars_home_path(timeframe:, car: car_param)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now? || timeframe.hours?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    #
    # The rates per 100 km read a window around each day, so these days count, too.
    Sensor::Summarizer.new(Car::DailyRates.for(timeframe, cars).missing_or_stale_days).call
  end

  def data_now
    data =
      Sensor::Query::Latest.new(
        [
          :wallbox_power,
          :wallbox_car_connected,
          *cars.flat_map { |car| Sensor::Cars::ROLES.map { Sensor::Cars.sensor_name(it, car.id) } },
        ],
      ).call
    Car::Balance.new(data, cars:)
  end

  def data_range
    data =
      Sensor::Query::Total
        .new(timeframe) do |q|
          q.sum :wallbox_power, :sum

          # The distance is only available through the daily summary,
          # which is not populated for hourly (sub-day) timeframes.
          next if timeframe.hours?

          cars.each do |car|
            q.sum Sensor::Cars.sensor_name(:car_mileage, car.id)
          end
          q.avg Sensor::Cars.sensor_name(:car_max_range, cars.sole.id), :avg if cars.one?
        end
        .call

    Car::Balance.new(data, cars:)
  end
end
