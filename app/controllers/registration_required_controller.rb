class RegistrationRequiredController < ApplicationController
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  layout 'blank'

  def show
    redirect_to root_path unless UpdateCheck.registration_grace_period_expired?
  end
end
