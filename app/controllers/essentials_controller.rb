class EssentialsController < ApplicationController
  def index
  end

  private

  helper_method def tiles
    [
      { field: 'inverter_power', timeframe: 'now' },
      { field: 'inverter_power', timeframe: Date.current.strftime('%Y-%m-%d') },
      { field: 'inverter_power', timeframe: Date.current.strftime('%Y-%m') },
      { field: 'inverter_power', timeframe: Date.current.strftime('%Y') },
      { field: 'inverter_power', timeframe: 'all' },
      { field: 'savings', timeframe: Date.current.strftime('%Y') },
    ]
  end
end
