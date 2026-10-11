class ApplicationController < ActionController::Base
  include Lockup
  include AutoLocale
  include MainNavigation
  include BrowserCheck

  default_form_builder TailwindFormBuilder

  # Marks the page as admin-only for MainNavigation, which needs to know where
  # a logout returns to. Rails evaluates the callback conditions (only:,
  # except:, if:) before it calls this, so the flag is set exactly for the
  # actions that really need the admin.
  def admin_required!
    @admin_only_page = true

    admin? || raise(ForbiddenError)
  end

  helper_method def admin?
    cookies.signed[:admin] == true
  end

  def turbo_stream_update_flash
    turbo_stream.update 'flash' do
      render_to_string AppFlash::Component.new(notice:, alert:), layout: false
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

  # The names of the cars are personal, so a guest sees their numbers
  before_action { Current.car_names_hidden = !admin? }

  before_action :check_for_registration
  before_action :check_for_sponsoring

  private

  def check_for_registration
    return unless UpdateCheck.registration_grace_period_expired?

    redirect_to(registration_required_path)
  end

  def check_for_sponsoring
    return unless UpdateCheck.prompt?
    return if UpdateCheck.skipped_prompt?

    redirect_to(sponsoring_path)
  end

  # Override this method to set a custom timeframe
  def timeframe
  end

  # The parameters of a selection beside the timeframe, for example the car
  # of the car page. Each link to the same page keeps them, and a link to
  # another page does not get them (see ApplicationHelper#selection_params).
  def selection_params = {}

  # The options of the charts of a selection, for example the cars of the
  # car page (see Sensor::Definitions::Base#chart). Each chart of the page
  # gets them (see ApplicationHelper#chart_options).
  def chart_options = {}
end
