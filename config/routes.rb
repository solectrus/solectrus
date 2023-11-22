# == Route Map
#
#        Prefix Verb   URI Pattern                                         Controller#Action
#          root GET    /(:field)(/:timeframe)(.:format)                    home#index {:field=>/inverter_power|house_power|grid_power|bat_power|bat_fuel_charge|wallbox_charge_power|case_temp|autarky|consumption|savings/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#         stats GET    /stats/:field(/:timeframe)(.:format)                stats#index {:field=>/inverter_power|house_power|grid_power|bat_power|bat_fuel_charge|wallbox_charge_power|case_temp|autarky|consumption|savings/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#        charts GET    /charts/:field(/:timeframe)(.:format)               charts#index {:field=>/inverter_power|house_power|grid_power|bat_power|bat_fuel_charge|wallbox_charge_power|case_temp|autarky|consumption|savings/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#         tiles GET    /tiles/:field(/:timeframe)(.:format)                tiles#show {:field=>/inverter_power|house_power|grid_power|bat_power|bat_fuel_charge|wallbox_charge_power|case_temp|autarky|consumption|savings/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#    essentials GET    /essentials(.:format)                               essentials#index
#         top10 GET    /top10(/:period)(/:field)(/:calc)(/:sort)(.:format) top10#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :field=>/inverter_power|house_power|grid_power_plus|grid_power_minus|bat_power_minus|bat_power_plus|wallbox_charge_power/}
#   top10_chart GET    /top10-chart/:period/:field/:calc/:sort(.:format)   top10_chart#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :field=>/inverter_power|house_power|grid_power_plus|grid_power_minus|bat_power_minus|bat_power_plus|wallbox_charge_power/}
#   new_session GET    /login(.:format)                                    sessions#new
#      sessions POST   /login(.:format)                                    sessions#create
#       session DELETE /logout(.:format)                                   sessions#destroy
#  registration GET    /registration(/:status)(.:format)                   registration#show
# edit_settings GET    /settings(.:format)                                 settings#edit
#      settings PATCH  /settings(.:format)                                 settings#update
#               PUT    /settings(.:format)                                 settings#update
#        prices GET    /settings/prices(/:name)(.:format)                  prices#index {:name=>/electricity|feed_in/}
#               GET    /settings/prices(.:format)                          prices#index
#               POST   /settings/prices(.:format)                          prices#create
#     new_price GET    /settings/prices/new(.:format)                      prices#new
#    edit_price GET    /settings/prices/:id/edit(.:format)                 prices#edit
#         price GET    /settings/prices/:id(.:format)                      prices#show
#               PATCH  /settings/prices/:id(.:format)                      prices#update
#               PUT    /settings/prices/:id(.:format)                      prices#update
#               DELETE /settings/prices/:id(.:format)                      prices#destroy

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', :as => :rails_health_check

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?
  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints field: Regexp.new(Senec::FIELDS_COMBINED.join('|'), false) do
    constraints timeframe: Timeframe.regex do
      get '/(/:field)(/:timeframe)', to: 'home#index', as: :root
      get '/stats/:field(/:timeframe)', to: 'stats#index', as: :stats
      get '/charts/:field(/:timeframe)', to: 'charts#index', as: :charts
      get '/tiles/:field(/:timeframe)', to: 'tiles#show', as: :tiles

      # Redirect old routes
      get '/:period/:field/(:timestamp)', to: redirect('/%{field}')
    end
  end

  resources :essentials, only: :index

  constraints period: /day|week|month|year/,
              calc: /sum|max/,
              sort: /asc|desc/,
              field: Regexp.new(Senec::POWER_FIELDS.join('|'), false) do
    get '/top10/(:period)/(:field)/(:calc)/(:sort)',
        to: 'top10#index',
        as: :top10
    get '/top10-chart/:period/:field/:calc/:sort',
        to: 'top10_chart#index',
        as: :top10_chart
  end

  get '/login', to: 'sessions#new', as: :new_session
  post '/login', to: 'sessions#create', as: :sessions
  delete '/logout', to: 'sessions#destroy', as: :session
  get '/registration/(:status)', to: 'registration#show', as: :registration

  get '/favicon.ico', to: redirect('/favicon-196.png')

  resource :settings, only: %i[edit update], path_names: { edit: '' }
  scope :settings do
    resources :prices, constraints: { name: Regexp.union(Price.names.keys) } do
      get '(:name)', on: :collection, action: :index, as: ''
    end
  end
end
