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

  def respond_with_flash(notice: nil, alert: nil)
    flash.now[:notice] = notice
    flash.now[:alert] = alert

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
                 turbo_stream.update('flash') do
                   ApplicationController.render(
                     AppFlash::Component.new(notice:, alert:),
                     layout: false,
                   )
                 end,
               ]
      end
    end
  end
end
