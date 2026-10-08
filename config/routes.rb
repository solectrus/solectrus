# == Route Map
#
# Routes for application:
#                            Prefix Verb             URI Pattern                                                   Controller#Action
#                      health_check GET              /up(.:format)                                                 health#show
#                skip_browser_check GET              /skip-browser-check(.:format)                                 application#skip_browser_check
#                          manifest GET              /manifest.webmanifest                                         manifest#show
#                          lookbook                  /lookbook                                                     Lookbook::Engine
#                     lockup_unlock GET              /lockup/unlock(.:format)                                      lockup#unlock
#                            unlock POST             /lockup/unlock(.:format)                                      lockup#unlock
#                               mcp POST             /mcp(.:format)                                                mcp#handle
#                                   GET              /mcp(.:format)                                                mcp_info#show
#                                   DELETE|PUT|PATCH /mcp(.:format)                                                mcp#unsupported_method
#                                   GET              /.well-known/oauth-protected-resource(.:format)               oauth/metadata#protected_resource
#                                   GET              /.well-known/oauth-protected-resource/mcp(.:format)           oauth/metadata#protected_resource
#                                   GET              /.well-known/oauth-authorization-server(.:format)             oauth/metadata#authorization_server
#                                   GET              /.well-known/openid-configuration(.:format)                   oauth/metadata#openid_configuration
#                    oauth_register POST             /oauth/register(.:format)                                     oauth/registrations#create
#                   oauth_authorize GET              /oauth/authorize(.:format)                                    oauth/authorizations#new
#                                   POST             /oauth/authorize(.:format)                                    oauth/authorizations#create
#                       oauth_token POST             /oauth/token(.:format)                                        oauth/tokens#create
#                          forecast GET              /forecast(.:format)                                           forecast/home#index
#                    forecast_chart GET              /forecast/:id(.:format)                                       forecast/charts#show {id: /inverter_power|outdoor_temp/}
#                      balance_home GET              /(:sensor_name)(/:timeframe)(.:format)                        balance/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     balance_stats GET              /stats/:sensor_name(/:timeframe)(.:format)                    balance/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    balance_charts GET              /charts/:sensor_name(/:timeframe)(.:format)                   balance/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     heatpump_home GET              /heatpump(/:sensor_name)(/:timeframe)(.:format)               heatpump/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    heatpump_stats GET              /heatpump/stats/:sensor_name(/:timeframe)(.:format)           heatpump/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                   heatpump_charts GET              /heatpump/charts/:sensor_name(/:timeframe)(.:format)          heatpump/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     inverter_home GET              /inverter(/:sensor_name)(/:timeframe)(.:format)               inverter/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    inverter_stats GET              /inverter/stats/:sensor_name(/:timeframe)(.:format)           inverter/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                   inverter_charts GET              /inverter/charts/:sensor_name(/:timeframe)(.:format)          inverter/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                        house_home GET              /house(/:sensor_name)(/:timeframe)(.:format)                  house/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                       house_stats GET              /house/stats/:sensor_name(/:timeframe)(.:format)              house/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                      house_charts GET              /house/charts/:sensor_name(/:timeframe)(.:format)             house/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                         cars_home GET              /cars(/:car)(/:sensor_name)(/:timeframe)(.:format)            cars/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/, car: /\d/, sensor_name: /(?!(?:\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all)\b)[a-z]\w*/}
#                        cars_stats GET              /cars(/:car)/stats(/:sensor_name)(/:timeframe)(.:format)      cars/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/, car: /\d/, sensor_name: /(?!(?:\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all)\b)[a-z]\w*/}
#                       cars_charts GET              /cars(/:car)/charts/:sensor_name(/:timeframe)(.:format)       cars/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/, car: /\d/, sensor_name: /(?!(?:\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all)\b)[a-z]\w*/}
#                             tiles GET              /tiles/:sensor_name(/:timeframe)(.:format)                    tiles#show {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                          insights GET              /insights/:sensor_name(/:timeframe)(.:format)                 insights#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                           summary GET              /summaries/:date(.:format)                                    summaries#show
#                         summaries DELETE           /summaries(.:format)                                          summaries#reset
#                        essentials GET              /essentials(.:format)                                         essentials#index
#              details_amortization GET              /amortization/details(.:format)                               amortization#details
#              returns_amortization GET              /amortization/returns(.:format)                               amortization#returns
#              content_amortization GET              /amortization/content(.:format)                               amortization#content
#                      amortization GET              /amortization(.:format)                                       amortization#show
#                                   PATCH            /amortization(.:format)                                       amortization#update
#                                   PUT              /amortization(.:format)                                       amortization#update
#                             top10 GET              /top10(/:period)(/:sensor_name)(/:calc)(/:sort)(.:format)     top10#index {period: /day|week|month|year/, calc: /sum|max|avg|min/, sort: /asc|desc/}
#                       top10_chart GET              /top10-chart/:period/:sensor_name/:calc/:sort(.:format)       top10_chart#index {period: /day|week|month|year/, calc: /sum|max|avg|min/, sort: /asc|desc/}
#                       new_session GET              /login(.:format)                                              sessions#new
#                          sessions POST             /login(.:format)                                              sessions#create
#                           session DELETE           /logout(.:format)                                             sessions#destroy
#                            locale PATCH            /locale(.:format)                                             locales#update
#                                   PUT              /locale(.:format)                                             locales#update
#              latest_notifications GET              /notifications/latest(.:format)                               notifications#latest
#         mark_as_read_notification PATCH            /notifications/:id/mark_as_read(.:format)                     notifications#mark_as_read
#                     notifications GET              /notifications(.:format)                                      notifications#index
#                      notification GET              /notifications/:id(.:format)                                  notifications#show
#                      registration GET              /registration(/:status)(.:format)                             registration#show
#             registration_required GET              /registration-required(.:format)                              registration_required#show
#                        sponsoring GET              /sponsoring(.:format)                                         sponsorings#show
#                                   GET              /favicon.ico(.:format)                                        redirect(301, /favicon-196.png)
#                                   GET              /apple-touch-icon.png(.:format)                               redirect(301, /apple-icon-180.png)
#                                   GET              /apple-touch-icon-precomposed.png(.:format)                   redirect(301, /apple-icon-180.png)
#             edit_settings_general GET              /settings/general(.:format)                                   settings/generals#edit
#                  settings_general PATCH            /settings/general(.:format)                                   settings/generals#update
#                                   PUT              /settings/general(.:format)                                   settings/generals#update
#             edit_settings_sensors GET              /settings/sensors(.:format)                                   settings/sensors#edit
#                  settings_sensors PATCH            /settings/sensors(.:format)                                   settings/sensors#update
#                                   PUT              /settings/sensors(.:format)                                   settings/sensors#update
#                   settings_prices GET              /settings/prices(/:name)(.:format)                            settings/prices#index {name: /electricity|feed_in/}
#                                   GET              /settings/prices(.:format)                                    settings/prices#index
#                                   POST             /settings/prices(.:format)                                    settings/prices#create
#                new_settings_price GET              /settings/prices/new(.:format)                                settings/prices#new
#               edit_settings_price GET              /settings/prices/:id/edit(.:format)                           settings/prices#edit
#                    settings_price GET              /settings/prices/:id(.:format)                                settings/prices#show
#                                   PATCH            /settings/prices/:id(.:format)                                settings/prices#update
#                                   PUT              /settings/prices/:id(.:format)                                settings/prices#update
#                                   DELETE           /settings/prices/:id(.:format)                                settings/prices#destroy
#                     settings_cars GET              /settings/cars(.:format)                                      settings/cars#index
#                 edit_settings_car GET              /settings/cars/:id/edit(.:format)                             settings/cars#edit
#                      settings_car PATCH            /settings/cars/:id(.:format)                                  settings/cars#update
#                                   PUT              /settings/cars/:id(.:format)                                  settings/cars#update
#                   settings_places GET              /settings/places(.:format)                                    settings/places#index
#               edit_settings_place GET              /settings/places/:id/edit(.:format)                           settings/places#edit
#                    settings_place PATCH            /settings/places/:id(.:format)                                settings/places#update
#                                   PUT              /settings/places/:id(.:format)                                settings/places#update
#    visibility_settings_cash_flows PATCH            /settings/cash_flows/visibility(.:format)                     settings/cash_flows#visibility
#               settings_cash_flows GET              /settings/cash_flows(.:format)                                settings/cash_flows#index
#                                   POST             /settings/cash_flows(.:format)                                settings/cash_flows#create
#            new_settings_cash_flow GET              /settings/cash_flows/new(.:format)                            settings/cash_flows#new
#           edit_settings_cash_flow GET              /settings/cash_flows/:id/edit(.:format)                       settings/cash_flows#edit
#                settings_cash_flow PATCH            /settings/cash_flows/:id(.:format)                            settings/cash_flows#update
#                                   PUT              /settings/cash_flows/:id(.:format)                            settings/cash_flows#update
#                                   DELETE           /settings/cash_flows/:id(.:format)                            settings/cash_flows#destroy
#                          settings GET              /settings(.:format)                                           redirect(301, /settings/general)
#                     cars_location GET              /cars/location/:car(.:format)                                 cars/locations#show {car: /\d+/}
#                        cars_place GET              /cars/location/:car/place(.:format)                           cars/places#show {car: /\d+/}
#                cars_place_tooltip GET              /cars(/:car)/places/:place/tooltip/:timeframe(.:format)       cars/place_tooltips#show {car: /\d/, timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                       cars_visits GET              /cars(/:car)(/places/:place)/visits(/:timeframe)(.:format)    cars/visits#index {car: /\d/, place: /\d+/, timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#            cars_charging_sessions GET              /cars(/:car)/charging_sessions(/:kind)(/:timeframe)(.:format) cars/charging_sessions#index {car: /(?-mix:\d)|unassigned|guest/, kind: /wallbox|offsite/, timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                                   POST             /cars/charging_sessions(.:format)                             cars/charging_sessions#create
#         new_cars_charging_session GET              /cars/charging_sessions/new(.:format)                         cars/charging_sessions#new
#        edit_cars_charging_session GET              /cars/charging_sessions/:id/edit(.:format)                    cars/charging_sessions#edit
#             cars_charging_session PATCH            /cars/charging_sessions/:id(.:format)                         cars/charging_sessions#update
#                                   PUT              /cars/charging_sessions/:id(.:format)                         cars/charging_sessions#update
#                                   DELETE           /cars/charging_sessions/:id(.:format)                         cars/charging_sessions#destroy
#                              root GET              /                                                             balance/home#index
#  turbo_recede_historical_location GET              /recede_historical_location(.:format)                         turbo/native/navigation#recede
#  turbo_resume_historical_location GET              /resume_historical_location(.:format)                         turbo/native/navigation#resume
# turbo_refresh_historical_location GET              /refresh_historical_location(.:format)                        turbo/native/navigation#refresh
#
# Routes for Lookbook::Engine:
#                Prefix Verb URI Pattern              Controller#Action
#                 cable      /cable                   #<ActionCable::Server::Base:0x000000012cb30100 @config=#<ActionCable::Server::Configuration:0x000000012cb30150 @log_tags=[], @connection_class=#<Proc:0x000000012cb91748 /Users/ledermann/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/lookbook-2.3.15/lib/lookbook/cable/cable.rb:48 (lambda)>, @worker_pool_size=4, @disable_request_forgery_protection=false, @allow_same_origin_as_host=true, @filter_parameters=[], @health_check_application=#<Proc:0x000000012cb91838 /Users/ledermann/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/actioncable-8.1.4/lib/action_cable/server/configuration.rb:32 (lambda)>, @cable={"adapter" => "async"}, @mount_path=nil, @logger=#<ActiveSupport::BroadcastLogger:0x000000012a0ccc88 @broadcasts=[#<ActiveSupport::Logger:0x000000012bd78d50 @level=0, @progname=nil, @default_formatter=#<Logger::Formatter:0x000000012a0ea788 @datetime_format=nil>, @formatter=#<ActiveSupport::Logger::SimpleFormatter:0x000000012a0cd8b8 @datetime_format=nil, @thread_key="activesupport_tagged_logging_tags:7376">, @logdev=#<Logger::LogDevice:0x000000012bd7ae20 @shift_period_suffix="%Y%m%d", @shift_size=104857600, @shift_age=1, @filename="/Users/ledermann/Projects/solectrus/solectrus/log/development.log", @dev=#<File:/Users/ledermann/Projects/solectrus/solectrus/log/development.log>, @binmode=false, @reraise_write_errors=[], @skip_header=false, @mon_data=#<Monitor:0x000000012bd7aba0>, @mon_data_owner_object_id=6008>, @level_override={}, @local_level_key=:logger_thread_safe_level_6016>], @progname="Broadcast">>, @mutex=#<Monitor:0x000000012cb30060>, @pubsub=nil, @worker_pool=nil, @event_loop=nil, @remote_connections=nil>
#         lookbook_home GET  /                        lookbook/application#index
#   lookbook_page_index GET  /pages(.:format)         lookbook/pages#index
#         lookbook_page GET  /pages/*path(.:format)   lookbook/pages#show
#     lookbook_previews GET  /previews(.:format)      lookbook/previews#index
#      lookbook_preview GET  /preview/*path(.:format) lookbook/previews#show
#      lookbook_inspect GET  /inspect/*path(.:format) lookbook/inspector#show
# lookbook_embed_lookup GET  /embed(.:format)         lookbook/embeds#lookup
#        lookbook_embed GET  /embed/*path(.:format)   lookbook/embeds#show
#                       GET  /*path(.:format)         lookbook/application#not_found

# Routing constraints that defer sensor validation to request time
# This avoids loading Sensor::Registry when routes.rb is parsed
class SensorConstraint
  def initialize(method_name)
    @method_name = method_name
  end

  def matches?(request)
    sensor_name = request.params[:sensor_name]&.to_sym
    return true unless sensor_name

    sensor = Sensor::Registry.find(sensor_name)
    sensor&.public_send(@method_name) || false
  end
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'health#show', :as => :health_check
  get 'skip-browser-check', to: 'application#skip_browser_check'

  # Rendered by Rails, so the theme colors stay in one place (ThemeConfig).
  # format: false keeps the dot in the path instead of parsing an extension.
  get 'manifest.webmanifest',
      to: 'manifest#show',
      as: :manifest,
      format: false

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  scope :lockup do
    get 'unlock', to: 'lockup#unlock', as: :lockup_unlock
    post 'unlock', to: 'lockup#unlock'
  end

  # MCP endpoint plus the OAuth 2.1 server protecting it, see
  # config/routes/mcp.rb
  draw :mcp

  get '/forecast', to: 'forecast/home#index', as: :forecast

  scope :forecast, module: :forecast do
    get '/:id',
        to: 'charts#show',
        as: :forecast_chart,
        constraints: {
          id: /inverter_power|outdoor_temp/,
        }
  end

  constraints SensorConstraint.new(:chart_enabled?) do
    constraints timeframe: Timeframe::REGEX do
      # Balance
      get '/(/:sensor_name)(/:timeframe)',
          to: 'balance/home#index',
          as: :balance_home
      get '/stats/:sensor_name(/:timeframe)',
          to: 'balance/stats#index',
          as: :balance_stats
      get '/charts/:sensor_name(/:timeframe)',
          to: 'balance/charts#index',
          as: :balance_charts

      # The other home pages. The car page has the selected car in front
      # (see CarSelection).
      #
      # A page whose live view has no chart has no sensor in the address of
      # its live view and its stats: /cars/now. A sensor name is never a
      # timeframe, so the timeframe takes the place of the missing sensor.
      sensor_name_not_timeframe = /(?!(?:#{Timeframe::REGEX.source})\b)[a-z]\w*/

      (Sensor::HomePage.all - [:balance]).each do |item|
        with_car = item == :cars
        with_sensor = Sensor::HomePage.live_chart?(item)

        car = with_car ? '(/:car)' : ''
        stats_sensor = with_sensor ? '/:sensor_name' : '(/:sensor_name)'
        constraints = {
          car: (CarSelection::CAR if with_car),
          sensor_name: (sensor_name_not_timeframe unless with_sensor),
        }.compact

        get "/#{item}#{car}(/:sensor_name)(/:timeframe)",
            to: "#{item}/home#index",
            as: :"#{item}_home",
            constraints: constraints
        get "/#{item}#{car}/stats#{stats_sensor}(/:timeframe)",
            to: "#{item}/stats#index",
            as: :"#{item}_stats",
            constraints: constraints
        get "/#{item}#{car}/charts/:sensor_name(/:timeframe)",
            to: "#{item}/charts#index",
            as: :"#{item}_charts",
            constraints: constraints
      end

      # Tiles
      get '/tiles/:sensor_name(/:timeframe)', to: 'tiles#show', as: :tiles

      # Insights
      get '/insights/:sensor_name(/:timeframe)',
          to: 'insights#index',
          as: :insights
    end
  end

  resources :summaries, only: :show, param: :date
  delete '/summaries', to: 'summaries#reset'

  resources :essentials, only: :index

  resource :amortization, only: %i[show update], controller: :amortization do
    get :details, on: :member
    get :returns, on: :member
    # The calculation, lazily loaded into the detail frame of any of the views
    # above (which one it is rides along as :view)
    get :content, on: :member
  end

  constraints period: /day|week|month|year/,
              calc: /sum|max|avg|min/,
              sort: /asc|desc/ do
    constraints SensorConstraint.new(:top10_enabled?) do
      get '/top10/(:period)/(:sensor_name)/(:calc)/(:sort)',
          to: 'top10#index',
          as: :top10
      get '/top10-chart/:period/:sensor_name/:calc/:sort',
          to: 'top10_chart#index',
          as: :top10_chart
    end
  end

  get '/login', to: 'sessions#new', as: :new_session
  post '/login', to: 'sessions#create', as: :sessions
  delete '/logout', to: 'sessions#destroy', as: :session

  resource :locale, only: :update

  resources :notifications, only: %i[index show] do
    collection { get :latest }
    member { patch :mark_as_read }
  end
  get '/registration/(:status)', to: 'registration#show', as: :registration
  get '/registration-required',
      to: 'registration_required#show',
      as: :registration_required
  get '/sponsoring', to: 'sponsorings#show', as: :sponsoring

  get '/favicon.ico', to: redirect('/favicon-196.png')
  get '/apple-touch-icon.png', to: redirect('/apple-icon-180.png')
  get '/apple-touch-icon-precomposed.png',
      to: redirect('/apple-icon-180.png')

  scope :settings, as: :settings, module: 'settings' do
    resource :general, only: %i[edit update], path_names: { edit: '' }
    resource :sensors, only: %i[edit update], path_names: { edit: '' }

    resources :prices, constraints: { name: Regexp.union(Price.names.keys) } do
      get '(:name)', on: :collection, action: :index, as: ''
    end

    resources :cars, only: %i[index edit update]
    resources :places, only: %i[index edit update]

    resources :cash_flows, except: :show do
      patch :visibility, on: :collection
    end
  end
  get '/settings', to: redirect('/settings/general')

  # The pages of the car page beside its sensor pages
  scope :cars, module: :cars, as: :cars do
    # The location of a car on a map that fills the window
    get 'location/:car',
        to: 'locations#show',
        as: :location,
        constraints: { car: /\d+/ }

    # The name of the place of a car, for the badge of the live view
    get 'location/:car/place',
        to: 'places#show',
        as: :place,
        constraints: { car: /\d+/ }

    # The tooltip of a place on the map of the places, with the selected car.
    # The place has no constraint, so the map can build the address with
    # ":id" in place of the id.
    get '(:car)/places/:place/tooltip/:timeframe',
        to: 'place_tooltips#show',
        as: :place_tooltip,
        constraints: { car: CarSelection::CAR, timeframe: Timeframe::REGEX }

    # The visits of the cars at the places, with the selected car and the
    # selected place in front
    get '(:car)(/places/:place)/visits(/:timeframe)',
        to: 'visits#index',
        as: :visits,
        constraints: { car: CarSelection::CAR, place: /\d+/, timeframe: Timeframe::REGEX }

    # The list of the charging sessions, with the selected car in front. The
    # list also selects the extras of its kind there (see CarSelection::EXTRAS).
    # Before the resources, so the list keeps the name.
    get '(:car)/charging_sessions(/:kind)(/:timeframe)',
        to: 'charging_sessions#index',
        as: :charging_sessions,
        constraints: {
          car: CarSelection::CAR_OR_EXTRA,
          kind: Regexp.union(ChargingSession.kinds.keys),
          timeframe: Timeframe::REGEX,
        }

    resources :charging_sessions, except: %i[index show]
  end

  root to: 'balance/home#index'
end
