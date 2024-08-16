ForbiddenError = Class.new(StandardError)
NotAcceptableError = Class.new(StandardError)

class ApplicationController < ActionController::Base
  include AutoLocale
  include TopNavigation
  default_form_builder TailwindFormBuilder

  allow_browser versions: {
                  safari: 17.2,
                  chrome: 118,
                  firefox: 121,
                  opera: 106,
                  ie: false,
                }, # TODO: Change to :modern when Cypress was updated to Electron 120+
                block:
                  lambda {
                    raise NotAcceptableError, t('errors.unsupported_browser')
                  },
                unless: -> { is_a?(ErrorsController) }

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
