# Browser-facing OAuth authorization endpoint. Renders a minimal page with a
# single password field; the admin password is the only credential. On success
# it mints a short-lived authorization-code JWT (bound to redirect_uri and
# code_challenge) and redirects back to the client.
#
# Plain ActionController::Base (not ApplicationController) to stay clear of the
# registration/sponsoring/admin before_actions - admin is proven here by the
# password, not by the session cookie.
class Oauth::AuthorizationsController < ActionController::Base
  include McpOauthGated
  # Pick up the locale from the browser/cookie, like the rest of the app.
  include AutoLocale

  default_form_builder TailwindFormBuilder
  layout 'blank'

  # A successful authorize POST 302-redirects to the client's external
  # redirect_uri. Browsers enforce `form-action` against that redirect target,
  # so the app-wide `form-action 'self'` would block it. The redirect_uri is
  # already validated server-side (see McpOauth::Redirect) and the
  # host is shown to the admin for consent, which is the real protection here,
  # so we simply allow any http(s) target in the CSP.
  content_security_policy do |policy|
    policy.form_action :self, :http, :https
  end

  # The admin password is the only credential guarding MCP access, and this is
  # the one endpoint that checks it without a session - reachable from the
  # internet on any instance following docs/MCP.md, which describes exposing it
  # through a tunnel so a browser-based AI client can connect. Unthrottled, it
  # answers guesses as fast as they arrive.
  #
  # Ten per three minutes costs a real admin nothing: they type the password
  # once, when connecting a client. It also holds for the login form, which
  # checks the same password (SessionsController).
  rate_limit to: 10,
             within: 3.minutes,
             only: :create,
             with: -> { render_too_many_attempts }

  def new
    return render_invalid_request unless valid_authorize_request?

    render :new
  end

  def create
    return render_invalid_request unless valid_authorize_request?

    unless McpOauth.valid_admin_password?(params[:password])
      # Generic error, no info leak about why it failed.
      flash.now[:alert] = t('oauth.authorize.error')
      return render :new, status: :unauthorized
    end

    callback =
      McpOauth::Urls.callback(
        authorize_params[:redirect_uri],
        code: mint_code,
        state: authorize_params[:state],
      )
    redirect_to callback, allow_other_host: true
  end

  private

  helper_method def title
    t('oauth.authorize.title')
  end

  # Host the access will be granted to, shown on the consent page so the admin
  # can vet where the authorization code is delivered. Normalized, so it reads
  # as the browser will resolve it (see McpOauth::Redirect.host).
  helper_method def client_host
    McpOauth::Redirect.host(authorize_params[:redirect_uri])
  end

  # A loopback callback means a client on the admin's own machine (e.g. the
  # mcp-remote bridge), so the consent page describes it as such instead of
  # showing the uninformative host "localhost".
  helper_method def local_client?
    McpOauth::Redirect.loopback?(authorize_params[:redirect_uri])
  end

  # An http callback to a host that is not the admin's own machine, so the
  # consent page can warn that the code crosses the network in cleartext.
  helper_method def insecure_client?
    McpOauth::Redirect.plaintext?(authorize_params[:redirect_uri])
  end

  helper_method def authorize_params
    @authorize_params ||=
      params.permit(
        :response_type,
        :redirect_uri,
        :state,
        :code_challenge,
        :code_challenge_method,
      )
  end

  def valid_authorize_request?
    authorize_params[:response_type] == 'code' &&
      authorize_params[:code_challenge_method] == 'S256' &&
      authorize_params[:code_challenge].present? &&
      McpOauth::Redirect.valid?(authorize_params[:redirect_uri])
  end

  def mint_code
    McpOauth.encode_code(
      base_url: request.base_url,
      redirect_uri: authorize_params[:redirect_uri],
      code_challenge: authorize_params[:code_challenge],
    )
  end

  def render_invalid_request
    # The redirect_uri is untrusted/invalid here, so we must NOT redirect to it.
    render :error, status: :bad_request
  end

  # Rendered rather than redirected for the same reason: the client is not
  # owed a callback here, and a redirect would hand the attempt straight back
  # to whoever is making it.
  def render_too_many_attempts
    render :throttled, status: :too_many_requests
  end
end
