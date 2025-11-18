class EssentialsController < ApplicationController
  include SummaryChecker

  def index
    load_missing_or_stale_summary_days(timeframe)
  end

  private

  helper_method def timeframe
    @timeframe ||= Timeframe.year
  end

  helper_method def title
    t('layout.essentials')
  end

  helper_method def tiles
    [
      { sensor_name: 'inverter_power', timeframe: 'now' },
      { sensor_name: 'inverter_power', timeframe: 'day' },
      { sensor_name: 'inverter_power', timeframe: 'month' },
      { sensor_name: 'inverter_power', timeframe: 'year' },
      { sensor_name: 'co2_reduction', timeframe: 'year' },
      { sensor_name: 'savings', timeframe: 'year' },
    ]
  end
end
