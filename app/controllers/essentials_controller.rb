class EssentialsController < ApplicationController
  def index
  end

  private

  helper_method def tiles
    [
      { field: 'inverter_power', timeframe: 'now' },
      { field: 'inverter_power', timeframe: 'day' },
      { field: 'inverter_power', timeframe: 'month' },
      { field: 'inverter_power', timeframe: 'year' },
      { field: 'inverter_power', timeframe: 'all' },
      { field: 'savings', timeframe: 'year' },
    ]
  end

  helper_method def static?
    params[:static] == 'true'
  end
end
