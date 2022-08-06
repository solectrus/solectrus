Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints period: /now|day|week|month|year|all/,
              field: Regexp.new(Senec::FIELDS_COMBINED.join('|'), false),
              timestamp: /\d{4}-\d{2}-\d{2}/ do
    get '/stats/:period/:field(/:timestamp)', to: 'stats#index', as: :stats
    get '/charts/:period/:field(/:timestamp)', to: 'charts#index', as: :charts
    get '/(:period)(/:field)(/:timestamp)', to: 'home#index', as: :root
  end

  constraints period: /day|month|year/,
              field: Regexp.new(Senec::POWER_FIELDS.join('|'), false) do
    get '/top10/:period/:field', to: 'top10#index', as: :top10
    get '/top10-chart/:period/:field', to: 'top10_chart#index', as: :top10_chart
  end

  get '/login', to: 'sessions#new', as: :new_session
  post '/login', to: 'sessions#create', as: :sessions
  delete '/logout', to: 'sessions#destroy', as: :session

  scope :settings do
    resources :prices
  end

  get '/about' => 'pages#about', :as => :about
end
