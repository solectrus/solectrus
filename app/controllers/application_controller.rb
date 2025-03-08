ForbiddenError = Class.new(StandardError)

class ApplicationController < ActionController::Base
  include AutoLocale
  include TopNavigation
  default_form_builder TailwindFormBuilder

  # Tailwind CSS 4 requires modern browser versions
  # https://tailwindcss.com/docs/compatibility
  allow_browser versions: { chrome: 111, safari: 16.4, firefox: 128, ie: false }

  def admin_required!
    admin? || raise(ForbiddenError)
  end

  helper_method def admin?
    cookies.signed[:admin] == true
  end

  def turbo_stream_update_flash
    turbo_stream.update 'flash' do
      ApplicationController.render(
        AppFlash::Component.new(notice:, alert:),
        layout: false,
      )
    end
  end

  def respond_with_flash(notice: nil, alert: nil)
    flash.now[:notice] = notice
    flash.now[:alert] = alert

    respond_to do |format|
      format.html
      format.turbo_stream { render turbo_stream: turbo_stream_update_flash }
    end
  end

  # Override this method to set a custom page title
  helper_method def title
  end

  before_action :check_for_sponsoring

  private

  def check_for_sponsoring
    return unless UpdateCheck.prompt?
    return if UpdateCheck.skipped_prompt?

    redirect_to(sponsoring_path)
  end

  # Override this method to set a custom timeframe
  def timeframe
  end
end
