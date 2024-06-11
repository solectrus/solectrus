# == Route Map
#
#                            Prefix Verb   URI Pattern                                          Controller#Action
#                rails_health_check GET    /up(.:format)                                        rails/health#show
#                          lookbook        /lookbook                                            Lookbook::Engine
#                              root GET    /(:sensor)(/:timeframe)(.:format)                    home#index {:sensor=>/inverter_power|inverter_power_forecast|house_power|heatpump_power|grid_power|grid_limit|battery_power|battery_soc|wallbox_power|case_temp|system_status|system_status_ok|autarky|consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                             stats GET    /stats/:sensor(/:timeframe)(.:format)                stats#index {:sensor=>/inverter_power|inverter_power_forecast|house_power|heatpump_power|grid_power|grid_limit|battery_power|battery_soc|wallbox_power|case_temp|system_status|system_status_ok|autarky|consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                            charts GET    /charts/:sensor(/:timeframe)(.:format)               charts#index {:sensor=>/inverter_power|inverter_power_forecast|house_power|heatpump_power|grid_power|grid_limit|battery_power|battery_soc|wallbox_power|case_temp|system_status|system_status_ok|autarky|consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                             tiles GET    /tiles/:sensor(/:timeframe)(.:format)                tiles#show {:sensor=>/inverter_power|inverter_power_forecast|house_power|heatpump_power|grid_power|grid_limit|battery_power|battery_soc|wallbox_power|case_temp|system_status|system_status_ok|autarky|consumption|savings|co2_reduction/, :timeframe=>/(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/}
#                                   GET    /:period/:sensor(/:timestamp)(.:format)              redirect(301, /%{sensor}) {:sensor=>/inverter_power|inverter_power_forecast|house_power|heatpump_power|grid_power|grid_limit|battery_power|battery_soc|wallbox_power|case_temp|system_status|system_status_ok|autarky|consumption|savings|co2_reduction/}
#                        essentials GET    /essentials(.:format)                                essentials#index
#                             top10 GET    /top10(/:period)(/:sensor)(/:calc)(/:sort)(.:format) top10#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :sensor=>/inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power/}
#                       top10_chart GET    /top10-chart/:period/:sensor/:calc/:sort(.:format)   top10_chart#index {:period=>/day|week|month|year/, :calc=>/sum|max/, :sort=>/asc|desc/, :sensor=>/inverter_power|house_power|heatpump_power|grid_import_power|grid_export_power|battery_charging_power|battery_discharging_power|wallbox_power/}
#                       new_session GET    /login(.:format)                                     sessions#new
#                          sessions POST   /login(.:format)                                     sessions#create
#                           session DELETE /logout(.:format)                                    sessions#destroy
#                      registration GET    /registration(/:status)(.:format)                    registration#show
#                                   GET    /favicon.ico(.:format)                               redirect(301, /favicon-196.png)
#                     edit_settings GET    /settings(.:format)                                  settings#edit
#                          settings PATCH  /settings(.:format)                                  settings#update
#                                   PUT    /settings(.:format)                                  settings#update
#                            prices GET    /settings/prices(/:name)(.:format)                   prices#index {:name=>/electricity|feed_in/}
#                                   GET    /settings/prices(.:format)                           prices#index
#                                   POST   /settings/prices(.:format)                           prices#create
#                         new_price GET    /settings/prices/new(.:format)                       prices#new
#                        edit_price GET    /settings/prices/:id/edit(.:format)                  prices#edit
#                             price GET    /settings/prices/:id(.:format)                       prices#show
#                                   PATCH  /settings/prices/:id(.:format)                       prices#update
#                                   PUT    /settings/prices/:id(.:format)                       prices#update
#                                   DELETE /settings/prices/:id(.:format)                       prices#destroy
#  turbo_recede_historical_location GET    /recede_historical_location(.:format)                turbo/native/navigation#recede
#  turbo_resume_historical_location GET    /resume_historical_location(.:format)                turbo/native/navigation#resume
# turbo_refresh_historical_location GET    /refresh_historical_location(.:format)               turbo/native/navigation#refresh
#
# Routes for Lookbook::Engine:
#                 cable      /cable                   #<ActionCable::Server::Base:0x0000000127dfd090 @config=#<ActionCable::Server::Configuration:0x0000000131df5e80 @log_tags=[], @connection_class=#<Proc:0x0000000131f3ddd8 /Users/ledermann/.rbenv/versions/3.3.2/lib/ruby/gems/3.3.0/gems/lookbook-2.3.1/lib/lookbook/cable/cable.rb:48 (lambda)>, @worker_pool_size=4, @disable_request_forgery_protection=false, @allow_same_origin_as_host=true, @filter_parameters=[], @health_check_application=#<Proc:0x0000000131f3dec8 /Users/ledermann/.rbenv/versions/3.3.2/lib/ruby/gems/3.3.0/gems/actioncable-7.1.3.4/lib/action_cable/server/configuration.rb:29 (lambda)>, @cable={"adapter"=>"async"}, @mount_path=nil, @logger=#<ActiveSupport::BroadcastLogger:0x0000000127f5dcc8 @broadcasts=[#<ActiveSupport::Logger:0x0000000124c78bc8 @level=0, @progname=nil, @default_formatter=#<Logger::Formatter:0x0000000127bf0ef0 @datetime_format=nil>, @formatter=#<ActiveSupport::Logger::SimpleFormatter:0x0000000127f5e1a0 @datetime_format=nil, @thread_key="activesupport_tagged_logging_tags:10840">, @logdev=#<Logger::LogDevice:0x0000000124c7ec58 @shift_period_suffix="%Y%m%d", @shift_size=104857600, @shift_age=1, @filename="/Users/ledermann/Projects/solectrus/solectrus/log/development.log", @dev=#<File:/Users/ledermann/Projects/solectrus/solectrus/log/development.log>, @binmode=false, @mon_data=#<Monitor:0x0000000127bf0d38>, @mon_data_owner_object_id=6240>, @level_override={}, @local_level_key=:logger_thread_safe_level_10820>], @progname="Broadcast", @formatter=#<ActiveSupport::Logger::SimpleFormatter:0x0000000127f5e1a0 @datetime_format=nil, @thread_key="activesupport_tagged_logging_tags:10840">>>, @mutex=#<Monitor:0x0000000131f3dd10>, @pubsub=nil, @worker_pool=nil, @event_loop=nil, @remote_connections=nil>
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
                Regexp.new(SensorConfig::COMBINED_SENSORS.join('|'), false) do
    constraints timeframe: Timeframe.regex do
      get '/(/:sensor)(/:timeframe)', to: 'home#index', as: :root
      get '/stats/:sensor(/:timeframe)', to: 'stats#index', as: :stats
      get '/charts/:sensor(/:timeframe)', to: 'charts#index', as: :charts
      get '/tiles/:sensor(/:timeframe)', to: 'tiles#show', as: :tiles

      # Redirect old routes
      get '/:period/:sensor/(:timestamp)', to: redirect('/%{sensor}')
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

  get '/favicon.ico', to: redirect('/favicon-196.png')

  resource :settings, only: %i[edit update], path_names: { edit: '' }
  scope :settings do
    resources :prices, constraints: { name: Regexp.union(Price.names.keys) } do
      get '(:name)', on: :collection, action: :index, as: ''
    end
  end
end
