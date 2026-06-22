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
  # already validated server-side (https or loopback only; see McpOauth) and the
  # target host is shown to the admin for consent, which is the real protection
  # here, so we simply allow any http(s) target in the CSP.
  content_security_policy do |policy|
    policy.form_action :self, :http, :https
  end

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
      McpOauth.callback_url(
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
  # can vet where the authorization code is delivered. Safe to parse: only
  # reached after valid_authorize_request? accepted the redirect_uri.
  helper_method def client_host
    URI.parse(authorize_params[:redirect_uri]).host
  end

  # A loopback callback means a client on the admin's own machine (e.g. the
  # mcp-remote bridge), so the consent page describes it as such instead of
  # showing the uninformative host "localhost".
  helper_method def local_client?
    McpOauth.loopback_redirect?(authorize_params[:redirect_uri])
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
      McpOauth.valid_redirect_uri?(authorize_params[:redirect_uri])
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
end
