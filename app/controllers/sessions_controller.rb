class SessionsController < ApplicationController
  include SafeReturnPath

  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  # The same credential the OAuth authorization page checks, and the same
  # reason to bound guesses: ADMIN_PASSWORD is the only thing between a
  # reachable instance and full access. Throttling one entrance and not the
  # other would only decide which door an attacker knocks on.
  rate_limit to: 10,
             within: 3.minutes,
             only: :create,
             with: -> { render_too_many_attempts }

  layout 'blank'

  def new
    redirect_to(balance_home_path) and return if admin?

    @admin_user = AdminUser.new
    @return_to = safe_return_path(params[:return_to].presence || referer_path)
  end

  def create
    @admin_user = AdminUser.new(permitted_params)

    if @admin_user.valid?
      start_admin_session

      flash[:notice] = t('login.welcome')
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(:redirect, redirect_path)
        end
        format.html { redirect_to redirect_path }
      end
    else
      @admin_user.password = nil
      @return_to = safe_return_path(params[:return_to])

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream:
                   turbo_stream.replace(
                     helpers.dom_id(@admin_user),
                     partial: 'form',
                   ),
                 status: :unauthorized
        end
        format.html { render :new, status: :unauthorized }
      end
    end
  end

  def destroy
    reset_session
    cookies.delete :admin

    flash[:notice] = t('login.bye')
    redirect_to safe_return_path(params[:return_to]), status: :see_other
  end

  private

  # Answered in the shape the form expects, so a throttled attempt reads like
  # a rejected one rather than breaking the page: the Turbo request replaces
  # the form, the plain one re-renders it. The reason rides on the model like
  # a validation error, because the blank layout renders no flash.
  def render_too_many_attempts
    @admin_user = AdminUser.new
    @admin_user.errors.add(:password, t('login.throttled'))
    @return_to = safe_return_path(params[:return_to])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream:
                 turbo_stream.replace(helpers.dom_id(@admin_user), partial: 'form'),
               status: :too_many_requests
      end
      format.html { render :new, status: :too_many_requests }
    end
  end

  def start_admin_session
    reset_session
    cookies.signed[:admin] = {
      value: true,
      max_age: 90.days.to_i,
      httponly: true,
      secure: request.ssl?,
      same_site: :lax,
    }
  end

  helper_method def title
    t('layout.login')
  end

  def permitted_params
    params.expect(admin_user: %i[username password])
  end

  def redirect_path
    safe_return_path(params[:return_to])
  end

  # Path (with query) of the page the user came from, used as default
  # return target when no explicit return_to param is present.
  def referer_path
    return if request.referer.blank?

    uri = URI.parse(request.referer)
    [uri.path, uri.query].compact_blank.join('?')
  rescue URI::InvalidURIError
    nil
  end
end
