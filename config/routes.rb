# == Route Map
#
#                            Prefix Verb   URI Pattern                                               Controller#Action
#                      health_check GET    /up(.:format)                                             health#show
#                skip_browser_check GET    /skip-browser-check(.:format)                             application#skip_browser_check
#                          lookbook        /lookbook                                                 Lookbook::Engine
#                              root GET    /(:sensor)(/:timeframe)(.:format)                         balance/home#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                                   GET    /stats/:sensor(/:timeframe)(.:format)                     balance/stats#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                                   GET    /charts/:sensor(/:timeframe)(.:format)                    balance/charts#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                        house_home GET    /house(/:sensor)(/:timeframe)(.:format)                   house/home#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                       house_stats GET    /house/stats/:sensor(/:timeframe)(.:format)               house/stats#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                      house_charts GET    /house/charts/:sensor(/:timeframe)(.:format)              house/charts#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     inverter_home GET    /inverter(/:sensor)(/:timeframe)(.:format)                inverter/home#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    inverter_stats GET    /inverter/stats/:sensor(/:timeframe)(.:format)            inverter/stats#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                   inverter_charts GET    /inverter/charts/:sensor(/:timeframe)(.:format)           inverter/charts#index {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                             tiles GET    /tiles/:sensor(/:timeframe)(.:format)                     tiles#show {sensor: /inverter_power|house_power|house_power_without_custom|heatpump_power|grid_power|battery_power|battery_soc|car_battery_soc|wallbox_power|case_temp|autarky|self_consumption|savings|co2_reduction|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/, timeframe: /\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                           summary GET    /summaries/:date(.:format)                                summaries#show
#                         summaries DELETE /summaries(.:format)                                      summaries#delete_all
#                        essentials GET    /essentials(.:format)                                     essentials#index
#                             top10 GET    /top10(/:period)(/:sensor)(/:calc)(/:sort)(.:format)      top10#index {period: /day|week|month|year/, calc: /sum|max/, sort: /asc|desc/, sensor: /inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/}
#                       top10_chart GET    /top10-chart/:period/:sensor/:calc/:sort(.:format)        top10_chart#index {period: /day|week|month|year/, calc: /sum|max/, sort: /asc|desc/, sensor: /inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power|inverter_power_1|inverter_power_2|inverter_power_3|inverter_power_4|inverter_power_5|custom_power_01|custom_power_02|custom_power_03|custom_power_04|custom_power_05|custom_power_06|custom_power_07|custom_power_08|custom_power_09|custom_power_10|custom_power_11|custom_power_12|custom_power_13|custom_power_14|custom_power_15|custom_power_16|custom_power_17|custom_power_18|custom_power_19|custom_power_20/}
#                       new_session GET    /login(.:format)                                          sessions#new
#                          sessions POST   /login(.:format)                                          sessions#create
#                           session DELETE /logout(.:format)                                         sessions#destroy
#                      registration GET    /registration(/:status)(.:format)                         registration#show
#                        sponsoring GET    /sponsoring(.:format)                                     sponsorings#show
#                                   GET    /favicon.ico(.:format)                                    redirect(301, /favicon-196.png)
#             edit_settings_general GET    /settings/general(.:format)                               settings/generals#edit
#                  settings_general PATCH  /settings/general(.:format)                               settings/generals#update
#                                   PUT    /settings/general(.:format)                               settings/generals#update
#             edit_settings_sensors GET    /settings/sensors(.:format)                               settings/sensors#edit
#                  settings_sensors PATCH  /settings/sensors(.:format)                               settings/sensors#update
#                                   PUT    /settings/sensors(.:format)                               settings/sensors#update
#                   settings_prices GET    /settings/prices(/:name)(.:format)                        settings/prices#index {name: /electricity|feed_in/}
#                                   GET    /settings/prices(.:format)                                settings/prices#index
#                                   POST   /settings/prices(.:format)                                settings/prices#create
#                new_settings_price GET    /settings/prices/new(.:format)                            settings/prices#new
#               edit_settings_price GET    /settings/prices/:id/edit(.:format)                       settings/prices#edit
#                    settings_price GET    /settings/prices/:id(.:format)                            settings/prices#show
#                                   PATCH  /settings/prices/:id(.:format)                            settings/prices#update
#                                   PUT    /settings/prices/:id(.:format)                            settings/prices#update
#                                   DELETE /settings/prices/:id(.:format)                            settings/prices#destroy
#                          settings GET    /settings(.:format)                                       redirect(301, /settings/general)
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
  get 'up' => 'health#show', :as => :health_check
  get 'skip-browser-check', to: 'application#skip_browser_check'

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?
  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  constraints sensor:
                Regexp.new(SensorConfig::CHART_SENSORS.join('|'), false) do
    constraints timeframe: Timeframe::REGEX do
      # Home (Root)
      get '/(/:sensor)(/:timeframe)', to: 'balance/home#index', as: :root
      get '/stats/:sensor(/:timeframe)', to: 'balance/stats#index'
      get '/charts/:sensor(/:timeframe)', to: 'balance/charts#index'

      # House / Inverter
      %i[house inverter].each do |item|
        get "/#{item}/(:sensor)(/:timeframe)",
            to: "#{item}/home#index",
            as: :"#{item}_home"
        get "/#{item}/stats/:sensor(/:timeframe)",
            to: "#{item}/stats#index",
            as: :"#{item}_stats"
        get "/#{item}/charts/:sensor(/:timeframe)",
            to: "#{item}/charts#index",
            as: :"#{item}_charts"
      end

      # Tiles
      get '/tiles/:sensor(/:timeframe)', to: 'tiles#show', as: :tiles
    end
  end

  resources :summaries, only: :show, param: :date
  delete '/summaries', to: 'summaries#delete_all'

  resources :essentials, only: :index

  constraints period: /day|week|month|year/,
              calc: /sum|max/,
              sort: /asc|desc/,
              sensor:
                Regexp.new(SensorConfig::TOP10_SENSORS.join('|'), false) do
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

  scope :settings, as: :settings, module: 'settings' do
    resource :general, only: %i[edit update], path_names: { edit: '' }
    resource :sensors, only: %i[edit update], path_names: { edit: '' }

    resources :prices, constraints: { name: Regexp.union(Price.names.keys) } do
      get '(:name)', on: :collection, action: :index, as: ''
    end
  end
  get '/settings', to: redirect('/settings/general')

  DeprecatedRoutesRedirect.draw(self)
end
