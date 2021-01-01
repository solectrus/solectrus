Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints timeframe: /current|last24h/ do
    get '/cards/(:timeframe)', to: 'cards#index', as: :cards
    get '/(:timeframe)', to: 'home#index', as: :root
  end
end
