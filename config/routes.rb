Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints timeframe: /now|day|week|month|year|all/,
              field: Regexp.new(Senec::FIELDS.join('|'), false),
              timestamp: /\d{4}-\d{2}-\d{2}/ do
    get '/stats/:timeframe/:field(/:timestamp)', to: 'stats#index', as: :stats
    get '/charts/:timeframe/:field(/:timestamp)', to: 'charts#index', as: :charts
    get '/(:timeframe)(/:field)(/:timestamp)', to: 'home#index', as: :root
  end

  constraints timeframe: /day|week|month|year/,
              field: Regexp.new(Senec::POWER_FIELDS.join('|'), false) do
    get '/top10/:timeframe/:field', to: 'top10#index', as: :top10
    get '/top10-chart/:timeframe/:field', to: 'top10_chart#index', as: :top10_chart
  end
end
