class SponsoringsController < ApplicationController
  skip_before_action :check_for_sponsoring

  # Nobody is asked for money who already pays, or who must not pay. Every
  # other reason ends, so the question stays open for them - and a reason this
  # app cannot name is not read as a settled one.
  SETTLED_REASONS = %i[sponsoring eligible_for_free].freeze
  private_constant :SETTLED_REASONS

  layout 'blank'

  def show
    if PremiumStatus.reason.in?(SETTLED_REASONS)
      redirect_to balance_home_path
    else
      render
    end
  end
end
