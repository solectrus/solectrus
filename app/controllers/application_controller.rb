ApplicationNotAuthenticated = Class.new(StandardError)

class ApplicationController < ActionController::Base
  include AutoLocale
  include TopNavigation
  default_form_builder TailwindFormBuilder

  rescue_from ApplicationNotAuthenticated do
    respond_to do |format|
      format.html { redirect_to new_session_path }
      format.any { head :unauthorized }
    end
  end

  def admin_required!
    admin? || raise(ApplicationNotAuthenticated)
  end

  helper_method def admin?
    cookies.signed[:admin] == true
  end
end
