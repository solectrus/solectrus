class Heatpump::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    render formats: :turbo_stream
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Summarizer.new(timeframe:).perform_now!
  end

  def calculations
    {
      outdoor_temp: :avg_outdoor_temp_avg,
      heatpump_power: :sum_heatpump_power_sum,
      heatpump_power_grid: :sum_heatpump_power_grid_sum,
      heatpump_heating_power: :sum_heatpump_heating_power_sum,
      heatpump_score: :avg_heatpump_score_avg,
    }
  end
end
