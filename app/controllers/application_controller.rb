ForbiddenError = Class.new(StandardError)

class ApplicationController < ActionController::Base
  include AutoLocale
  include TopNavigation
  default_form_builder TailwindFormBuilder

  def admin_required!
    admin? || raise(ForbiddenError)
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

  # Override this method to set a custom page title
  helper_method def title
  end
end
