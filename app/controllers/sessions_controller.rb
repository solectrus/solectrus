class SessionsController < ApplicationController
  def new
    redirect_to(root_path) and return if admin?

    @admin_user = AdminUser.new
  end

  def create
    @admin_user = AdminUser.new(permitted_params)

    if @admin_user.valid?
      cookies.permanent.signed[:admin] = true
      redirect_to referer_path || root_path
    else
      @admin_user.password = nil
      render :new, status: :unauthorized
    end
  end

  def destroy
    cookies.delete :admin

    redirect_to referer_path || root_path, status: :see_other
  end

  private

  def permitted_params
    params.require(:admin_user).permit(:username, :password)
  end

  def referer_path
    return unless request.referer

    uri = URI.parse(request.referer)
    [uri.path, uri.query].compact.join('?')
  end
end
