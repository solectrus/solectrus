class HomeController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  def index
    unless sensor && timeframe
      redirect_to(default_path)
      return
    end

    @completed = ensure_completed_summaries

    @missing_dates =
      if @completed
        []
      else
        Summarizer.records_to_update(
          from: timeframe.effective_beginning_date,
          to: timeframe.effective_ending_date,
        )
      end
  end

  private

  def ensure_completed_summaries
    return true if timeframe.now? || Summary.completed?(timeframe)
    return true if timeframe.future?

    Summarizer.perform_later!(
      from: timeframe.effective_beginning_date,
      to: timeframe.effective_ending_date,
    )

    false
  end

  def default_path
    root_path(sensor: sensor || redirect_sensor, timeframe: 'now')
  end

  # By default we want to show the current production, so we redirect to the inverter_power sensor.
  # But at night this does not make sense, so in this case we redirect to the house_power sensor.
  def redirect_sensor
    DayLight.active? ? :inverter_power : :house_power
  end
end
