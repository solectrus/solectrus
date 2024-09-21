# == Route Map
#
#                            Prefix Verb   URI Pattern                                               Controller#Action
#                rails_health_check GET    /up(.:format)                                             rails/health#show
#                          lookbook        /lookbook                                                 Lookbook::Engine
#                              root GET    /(:sensor)(/:timeframe)(.:format)                         home#index {:sensor=>/inverter_power|house_power|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                             stats GET    /stats/:sensor(/:timeframe)(.:format)                     stats#index {:sensor=>/inverter_power|house_power|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                            charts GET    /charts/:sensor(/:timeframe)(.:format)                    charts#index {:sensor=>/inverter_power|house_power|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                             tiles GET    /tiles/:sensor(/:timeframe)(.:format)                     tiles#show {:sensor=>/inverter_power|house_power|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                        essentials GET    /essentials(.:format)                                     essentials#index
#                             top10 GET    /top10(/:period)(/:sensor)(/:calc)(/:sort)(.:format)      top10#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :sensor=>/inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power/}
#                       top10_chart GET    /top10-chart/:period/:sensor/:calc/:sort(.:format)        top10_chart#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :sensor=>/inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power/}
#                       new_session GET    /login(.:format)                                          sessions#new
#                          sessions POST   /login(.:format)                                          sessions#create
#                           session DELETE /logout(.:format)                                         sessions#destroy
#                      registration GET    /registration(/:status)(.:format)                         registration#show
#                                   GET    /favicon.ico(.:format)                                    redirect(301, /favicon-196.png)
#                     edit_settings GET    /settings(.:format)                                       settings#edit
#                          settings PATCH  /settings(.:format)                                       settings#update
#                                   PUT    /settings(.:format)                                       settings#update
#                            prices GET    /settings/prices(/:name)(.:format)                        prices#index {:name=>/electricity|feed_in/}
#                                   GET    /settings/prices(.:format)                                prices#index
#                                   POST   /settings/prices(.:format)                                prices#create
#                         new_price GET    /settings/prices/new(.:format)                            prices#new
#                        edit_price GET    /settings/prices/:id/edit(.:format)                       prices#edit
#                             price GET    /settings/prices/:id(.:format)                            prices#show
#                                   PATCH  /settings/prices/:id(.:format)                            prices#update
#                                   PUT    /settings/prices/:id(.:format)                            prices#update
#                                   DELETE /settings/prices/:id(.:format)                            prices#destroy
#                         bat_power GET    /bat_power(.:format)                                      redirect(301, /battery_power)
#                                   GET    /bat_power/:timeframe(.:format)                           redirect(301, /battery_power/%{timeframe})
#                   bat_fuel_charge GET    /bat_fuel_charge(.:format)                                redirect(301, /battery_soc)
#                                   GET    /bat_fuel_charge/:timeframe(.:format)                     redirect(301, /battery_soc/%{timeframe})
#              wallbox_charge_power GET    /wallbox_charge_power(.:format)                           redirect(301, /wallbox_power)
#                                   GET    /wallbox_charge_power/:timeframe(.:format)                redirect(301, /wallbox_power/%{timeframe})
#                                   GET    /top10/:period/wallbox_charge_power/:calc/:sort(.:format) redirect(301, /top10/%{period}/wallbox_power/%{calc}/%{sort})
#                                   GET    /top10/:period/bat_power_minus/:calc/:sort(.:format)      redirect(301, /top10/%{period}/battery_charging_power/%{calc}/%{sort})
#                                   GET    /top10/:period/bat_power_plus/:calc/:sort(.:format)       redirect(301, /top10/%{period}/battery_discharging_power/%{calc}/%{sort})
#                                   GET    /top10/:period/grid_power_minus/:calc/:sort(.:format)     redirect(301, /top10/%{period}/grid_export_power/%{calc}/%{sort})
#                                   GET    /top10/:period/grid_power_plus/:calc/:sort(.:format)      redirect(301, /top10/%{period}/grid_import_power/%{calc}/%{sort})
#  turbo_recede_historical_location GET    /recede_historical_location(.:format)                     turbo/native/navigation#recede
#  turbo_resume_historical_location GET    /resume_historical_location(.:format)                     turbo/native/navigation#resume
# turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                    turbo/native/navigation#refresh
#
# Routes for Lookbook::Engine:
#         lookbook_home GET  /                        lookbook/application#index
#   lookbook_page_index GET  /pages(.:format)         lookbook/pages#index
#         lookbook_page GET  /pages/*path(.:format)   lookbook/pages#show
#     lookbook_previews GET  /previews(.:format)      lookbook/previews#index
#      lookbook_preview GET  /preview/*path(.:format) lookbook/previews#show
#      lookbook_inspect GET  /inspect/*path(.:format) lookbook/inspector#show
# lookbook_embed_lookup GET  /embed(.:format)         lookbook/embeds#lookup
#        lookbook_embed GET  /embed/*path(.:format)   lookbook/embeds#show
#                       GET  /*path(.:format)         lookbook/application#not_found

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', :as => :rails_health_check

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?
  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints sensor:
                Regexp.new(SensorConfig::CHART_SENSORS.join('|'), false) do
    constraints timeframe: Timeframe.regex do
      get '/(/:sensor)(/:timeframe)', to: 'home#index', as: :root
      get '/stats/:sensor(/:timeframe)', to: 'stats#index', as: :stats
      get '/charts/:sensor(/:timeframe)', to: 'charts#index', as: :charts
      get '/tiles/:sensor(/:timeframe)', to: 'tiles#show', as: :tiles
    end
  end

  resources :essentials, only: :index

  constraints period: /day|week|month|year/,
              calc: /sum|max/,
              sort: /asc|desc/,
              sensor:
                Regexp.new(SensorConfig::POWER_SENSORS.join('|'), false) do
    get '/top10/(:period)/(:sensor)/(:calc)/(:sort)',
        to: 'top10#index',
        as: :top10
    get '/top10-chart/:period/:sensor/:calc/:sort',
        to: 'top10_chart#index',
        as: :top10_chart
  end

  get '/login', to: 'sessions#new', as: :new_session
  post '/login', to: 'sessions#create', as: :sessions
  delete '/logout', to: 'sessions#destroy', as: :session
  get '/registration/(:status)', to: 'registration#show', as: :registration
  get '/sponsoring', to: 'sponsorings#show', as: :sponsoring

  get '/favicon.ico', to: redirect('/favicon-196.png')

  resource :settings, only: %i[edit update], path_names: { edit: '' }
  scope :settings do
    resources :prices, constraints: { name: Regexp.union(Price.names.keys) } do
      get '(:name)', on: :collection, action: :index, as: ''
    end
  end

  DeprecatedRoutesRedirect.draw(self)
end
