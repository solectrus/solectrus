Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?
  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints field: Regexp.new(Senec::FIELDS_COMBINED.join('|'), false) do
    constraints timeframe: Timeframe.regex do
      get '/(/:field)(/:timeframe)', to: 'home#index', as: :root
      get '/stats/:field(/:timeframe)', to: 'stats#index', as: :stats
      get '/charts/:field(/:timeframe)', to: 'charts#index', as: :charts

      # Redirect old routes
      get '/:period/:field/(:timestamp)', to: redirect('/%{field}')
    end

    # Redirect time shortcut routes
    constraints timeframe: /day|week|month|year/ do
      get '/(:field)/(:timeframe)',
          to:
            redirect(status: 302) { |path_params, _req|
              case path_params[:timeframe]
              when 'day'
                "/#{path_params[:field]}/#{Date.current.strftime('%Y-%m-%d')}"
              when 'week'
                "/#{path_params[:field]}/#{Date.current.strftime('%Y-W%V')}"
              when 'month'
                "/#{path_params[:field]}/#{Date.current.strftime('%Y-%m')}"
              when 'year'
                "/#{path_params[:field]}/#{Date.current.strftime('%Y')}"
              end
            }
    end
  end

  constraints period: /day|week|month|year/,
              sort: /asc|desc/,
              field: Regexp.new(Senec::POWER_FIELDS.join('|'), false) do
    get '/top10/:period/:field/:sort', to: 'top10#index', as: :top10
    get '/top10-chart/:period/:field/:sort',
        to: 'top10_chart#index',
        as: :top10_chart

    # Redirect old routes
    get '/top10/:period/:field', to: redirect('/top10/%{period}/%{field}/desc')
  end

  get '/login', to: 'sessions#new', as: :new_session
  post '/login', to: 'sessions#create', as: :sessions
  delete '/logout', to: 'sessions#destroy', as: :session

  get '/favicon.ico', to: redirect('/favicon-196.png')

  scope :settings do
    resources :prices
  end
end
