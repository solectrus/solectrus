# Base for the machine-facing OAuth endpoints (discovery, registration, token).
# An API controller: no session, no CSRF, JSON only. The browser-facing
# authorize page is a separate controller (see Oauth::AuthorizationsController).
class Oauth::BaseController < ActionController::API
  include McpOauthGated
end
