# == Route Map
#
# Routes for application:
#                            Prefix Verb   URI Pattern                                               Controller#Action
#                      health_check GET    /up(.:format)                                             health#show
#                skip_browser_check GET    /skip-browser-check(.:format)                             application#skip_browser_check
#                          lookbook        /lookbook                                                 Lookbook::Engine
#                     lockup_unlock GET    /lockup/unlock(.:format)                                  lockup#unlock
#                            unlock POST   /lockup/unlock(.:format)                                  lockup#unlock
#                               mcp POST   /mcp(.:format)                                            mcp#handle
#                                   GET    /mcp(.:format)                                            mcp_info#show
#                                   GET    /.well-known/oauth-protected-resource(.:format)           oauth/metadata#protected_resource
#                                   GET    /.well-known/oauth-protected-resource/mcp(.:format)       oauth/metadata#protected_resource
#                                   GET    /.well-known/oauth-authorization-server(.:format)         oauth/metadata#authorization_server
#                                   GET    /.well-known/openid-configuration(.:format)               oauth/metadata#openid_configuration
#                    oauth_register POST   /oauth/register(.:format)                                 oauth/registrations#create
#                   oauth_authorize GET    /oauth/authorize(.:format)                                oauth/authorizations#new
#                                   POST   /oauth/authorize(.:format)                                oauth/authorizations#create
#                       oauth_token POST   /oauth/token(.:format)                                    oauth/tokens#create
#                          forecast GET    /forecast(.:format)                                       forecast/home#index
#                    forecast_chart GET    /forecast/:id(.:format)                                   forecast/charts#show {id: /inverter_power|outdoor_temp/}
#                      balance_home GET    /(:sensor_name)(/:timeframe)(.:format)                    balance/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     balance_stats GET    /stats/:sensor_name(/:timeframe)(.:format)                balance/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    balance_charts GET    /charts/:sensor_name(/:timeframe)(.:format)               balance/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                        house_home GET    /house(/:sensor_name)(/:timeframe)(.:format)              house/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                       house_stats GET    /house/stats/:sensor_name(/:timeframe)(.:format)          house/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                      house_charts GET    /house/charts/:sensor_name(/:timeframe)(.:format)         house/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     heatpump_home GET    /heatpump(/:sensor_name)(/:timeframe)(.:format)           heatpump/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    heatpump_stats GET    /heatpump/stats/:sensor_name(/:timeframe)(.:format)       heatpump/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                   heatpump_charts GET    /heatpump/charts/:sensor_name(/:timeframe)(.:format)      heatpump/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                     inverter_home GET    /inverter(/:sensor_name)(/:timeframe)(.:format)           inverter/home#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                    inverter_stats GET    /inverter/stats/:sensor_name(/:timeframe)(.:format)       inverter/stats#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                   inverter_charts GET    /inverter/charts/:sensor_name(/:timeframe)(.:format)      inverter/charts#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                             tiles GET    /tiles/:sensor_name(/:timeframe)(.:format)                tiles#show {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                          insights GET    /insights/:sensor_name(/:timeframe)(.:format)             insights#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                  timeframe_select GET    /timeframe-select/:sensor_name(/:timeframe)(.:format)     timeframe_select#index {timeframe: /\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}|P\d{1,2}H|\d{4}-\d{2}-\d{2}|P\d{1,3}D|\d{4}-W\d{2}|\d{4}-\d{2}|P\d{1,2}M|\d{4}|P\d{1,2}Y|now|day|week|month|year|all/}
#                           summary GET    /summaries/:date(.:format)                                summaries#show
#                         summaries DELETE /summaries(.:format)                                      summaries#delete_all
#                        essentials GET    /essentials(.:format)                                     essentials#index
#              details_amortization GET    /amortization/details(.:format)                           amortization#details
#              returns_amortization GET    /amortization/returns(.:format)                           amortization#returns
#              content_amortization GET    /amortization/content(.:format)                           amortization#content
#                      amortization GET    /amortization(.:format)                                   amortization#show
#                                   PATCH  /amortization(.:format)                                   amortization#update
#                                   PUT    /amortization(.:format)                                   amortization#update
#                             top10 GET    /top10(/:period)(/:sensor_name)(/:calc)(/:sort)(.:format) top10#index {period: /day|week|month|year/, calc: /sum|max|avg|min/, sort: /asc|desc/}
#                       top10_chart GET    /top10-chart/:period/:sensor_name/:calc/:sort(.:format)   top10_chart#index {period: /day|week|month|year/, calc: /sum|max|avg|min/, sort: /asc|desc/}
#                       new_session GET    /login(.:format)                                          sessions#new
#                          sessions POST   /login(.:format)                                          sessions#create
#                           session DELETE /logout(.:format)                                         sessions#destroy
#                            locale PATCH  /locale(.:format)                                         locales#update
#                                   PUT    /locale(.:format)                                         locales#update
#              latest_notifications GET    /notifications/latest(.:format)                           notifications#latest
#         mark_as_read_notification PATCH  /notifications/:id/mark_as_read(.:format)                 notifications#mark_as_read
#                     notifications GET    /notifications(.:format)                                  notifications#index
#                      notification GET    /notifications/:id(.:format)                              notifications#show
#                      registration GET    /registration(/:status)(.:format)                         registration#show
#             registration_required GET    /registration-required(.:format)                          registration_required#show
#                        sponsoring GET    /sponsoring(.:format)                                     sponsorings#show
#                                   GET    /favicon.ico(.:format)                                    redirect(301, /favicon-196.png)
#                                   GET    /apple-touch-icon.png(.:format)                           redirect(301, /apple-icon-180.png)
#                                   GET    /apple-touch-icon-precomposed.png(.:format)               redirect(301, /apple-icon-180.png)
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
#    visibility_settings_cash_flows PATCH  /settings/cash_flows/visibility(.:format)                 settings/cash_flows#visibility
#               settings_cash_flows GET    /settings/cash_flows(.:format)                            settings/cash_flows#index
#                                   POST   /settings/cash_flows(.:format)                            settings/cash_flows#create
#            new_settings_cash_flow GET    /settings/cash_flows/new(.:format)                        settings/cash_flows#new
#           edit_settings_cash_flow GET    /settings/cash_flows/:id/edit(.:format)                   settings/cash_flows#edit
#                settings_cash_flow PATCH  /settings/cash_flows/:id(.:format)                        settings/cash_flows#update
#                                   PUT    /settings/cash_flows/:id(.:format)                        settings/cash_flows#update
#                                   DELETE /settings/cash_flows/:id(.:format)                        settings/cash_flows#destroy
#                          settings GET    /settings(.:format)                                       redirect(301, /settings/general)
#                              root GET    /                                                         balance/home#index
#  turbo_recede_historical_location GET    /recede_historical_location(.:format)                     turbo/native/navigation#recede
#  turbo_resume_historical_location GET    /resume_historical_location(.:format)                     turbo/native/navigation#resume
# turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                    turbo/native/navigation#refresh
#
# Routes for Lookbook::Engine:
#                Prefix Verb URI Pattern              Controller#Action
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

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  scope :lockup do
    get 'unlock', to: 'lockup#unlock', as: :lockup_unlock
    post 'unlock', to: 'lockup#unlock'
  end

  # Model Context Protocol endpoint for read-only data access by AI clients.
  # Disabled unless enabled in the settings; requires an OAuth access token.
  post '/mcp', to: 'mcp#handle'
  # A browser opening the endpoint (GET) would otherwise hit a bare 404. Show a
  # short guide on how to connect an AI client instead - gated the same way, so
  # it stays invisible when MCP is disabled or for non-sponsors.
  get '/mcp', to: 'mcp_info#show'

  # Stateless OAuth 2.1 (authorization code + PKCE) protecting the MCP endpoint,
  # plus the discovery documents. All gated on the same opt-in toggle as /mcp;
  # when MCP is disabled they behave as 404. Clients discover the endpoints from
  # the authorization-server metadata (which points them at /oauth/*).
  get '/.well-known/oauth-protected-resource',
      to: 'oauth/metadata#protected_resource'
  # RFC 9728 inserts the resource path after the well-known segment, so clients
  # request the metadata for the /mcp resource here. Same document as above.
  get '/.well-known/oauth-protected-resource/mcp',
      to: 'oauth/metadata#protected_resource'
  get '/.well-known/oauth-authorization-server',
      to: 'oauth/metadata#authorization_server'
  # We are an OAuth 2.1 server, not an OpenID Connect provider. Clients probe
  # this path during discovery; answer with a clean 404 instead of letting it
  # fall through to a logged RoutingError.
  get '/.well-known/openid-configuration',
      to: 'oauth/metadata#openid_configuration'

  scope :oauth, module: :oauth, as: :oauth do
    post 'register', to: 'registrations#create'
    get 'authorize', to: 'authorizations#new', as: :authorize
    post 'authorize', to: 'authorizations#create'
    post 'token', to: 'tokens#create'
  end

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

      # House / Heatpump / Inverter
      %i[house heatpump inverter].each do |item|
        get "/#{item}(/:sensor_name)(/:timeframe)",
            to: "#{item}/home#index",
            as: :"#{item}_home"
        get "/#{item}/stats/:sensor_name(/:timeframe)",
            to: "#{item}/stats#index",
            as: :"#{item}_stats"
        get "/#{item}/charts/:sensor_name(/:timeframe)",
            to: "#{item}/charts#index",
            as: :"#{item}_charts"
      end

      # Tiles
      get '/tiles/:sensor_name(/:timeframe)', to: 'tiles#show', as: :tiles

      # Insights
      get '/insights/:sensor_name(/:timeframe)',
          to: 'insights#index',
          as: :insights

      # Timeframe Select
      get '/timeframe-select/:sensor_name(/:timeframe)',
          to: 'timeframe_select#index',
          as: :timeframe_select
    end
  end

  resources :summaries, only: :show, param: :date
  delete '/summaries', to: 'summaries#delete_all'

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

    resources :cash_flows, except: :show do
      patch :visibility, on: :collection
    end
  end
  get '/settings', to: redirect('/settings/general')

  root to: 'balance/home#index'
end
