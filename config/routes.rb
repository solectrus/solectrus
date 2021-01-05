Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints timeframe: /now|day|week|month|year|all/,
              field: /inverter_power|house_power|grid_power_plus|grid_power_minus|bat_power_minus|bat_power_plus|bat_fuel_charge/ do
    get '/stats/(:timeframe)(/:field)', to: 'stats#index', as: :stats
    get '/graphs/(:timeframe)(/:field)', to: 'graphs#index', as: :graphs
    get '/(:timeframe)(/:field)', to: 'home#index', as: :root
  end
end
