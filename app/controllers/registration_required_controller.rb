class RegistrationRequiredController < ApplicationController
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  layout 'blank'

  def show
    return if UpdateCheck.registration_grace_period_expired?

    redirect_to balance_home_path
  end
end
