class EssentialsController < ApplicationController
  def index
  end

  private

  helper_method def title
    t('layout.essentials')
  end

  helper_method def tiles
    [
      { field: 'inverter_power', timeframe: 'now' },
      { field: 'inverter_power', timeframe: 'day' },
      { field: 'inverter_power', timeframe: 'month' },
      { field: 'inverter_power', timeframe: 'year' },
      { field: 'co2_savings', timeframe: 'year' },
      { field: 'savings', timeframe: 'year' },
    ]
  end
end
