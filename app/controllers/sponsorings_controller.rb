class SponsoringsController < ApplicationController
  skip_before_action :check_for_sponsoring

  layout 'blank'

  def show
    if UpdateCheck.eligible_for_free? || UpdateCheck.sponsoring?
      redirect_to root_path
    else
      render
    end
  end
end
