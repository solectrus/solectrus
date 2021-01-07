Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints timeframe: /now|day|week|month|year|all/,
              field: /inverter_power|house_power|grid_power_plus|grid_power_minus|bat_power_minus|bat_power_plus|bat_fuel_charge|wallbox/,
              timestamp: /\d{4}-\d{2}-\d{2}/ do
    get '/stats/:timeframe/:field(/:timestamp)', to: 'stats#index', as: :stats
    get '/charts/:timeframe/:field(/:timestamp)', to: 'charts#index', as: :charts
    get '/(:timeframe)(/:field)(/:timestamp)', to: 'home#index', as: :root
  end
end
