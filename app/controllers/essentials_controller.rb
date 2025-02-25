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
      { sensor: 'inverter_power', timeframe: 'now' },
      { sensor: 'inverter_power', timeframe: 'day' },
      { sensor: 'inverter_power', timeframe: 'month' },
      { sensor: 'inverter_power', timeframe: 'year' },
      { sensor: 'co2_reduction', timeframe: 'year' },
      { sensor: 'savings', timeframe: 'year' },
    ]
  end
end
