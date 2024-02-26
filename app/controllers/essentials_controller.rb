class EssentialsController < ApplicationController
  def index
  end

  private

  helper_method def title
    t('layout.essentials')
  end

  helper_method def tiles
    [
      { sensor: 'inverter_power', timeframe: 'now' },
      { sensor: 'inverter_power', timeframe: 'day' },
      { sensor: 'inverter_power', timeframe: 'month' },
      { sensor: 'inverter_power', timeframe: 'year' },
      { sensor: 'co2_savings', timeframe: 'year' },
      { sensor: 'savings', timeframe: 'year' },
    ]
  end
end
