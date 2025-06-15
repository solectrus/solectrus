class SessionsController < ApplicationController
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  def new
    redirect_to(root_path) and return if admin?

    @admin_user = AdminUser.new
  end

  def create
    @admin_user = AdminUser.new(permitted_params)

    if @admin_user.valid?
      cookies.permanent.signed[:admin] = true

      flash[:notice] = t('login.welcome')
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(:redirect, redirect_path)
        end
        format.html { redirect_to redirect_path }
      end
    else
      @admin_user.password = nil

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
    cookies.delete :admin

    flash[:notice] = t('login.bye')
    redirect_to root_path, status: :see_other
  end

  private

  helper_method def title
    t('layout.login')
  end

  def permitted_params
    params.expect(admin_user: %i[username password])
  end

  def redirect_path
    return root_path unless request.referer

    uri = URI.parse(request.referer)
    [uri.path, uri.query].compact.join('?')
  end
end
