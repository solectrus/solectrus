class LockupController < ApplicationController
  include SafeReturnPath

  skip_before_action :check_for_lockup
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  before_action :ensure_lockup_enabled

  # The codeword is the only thing between a locked instance and its pages, so
  # guesses are bounded here as on the login. Only a submitted form counts, a
  # visit to the form does not.
  rate_limit to: 10,
             within: 3.minutes,
             only: :unlock,
             if: -> { request.post? },
             with: -> { render_too_many_attempts }

  layout 'blank'

  def unlock
    @return_to = return_to

    # Until unlocked, the page answers 403, so crawlers do not take it as content
    codeword = lockup_params.dig(:lockup, :codeword)
    return render(:unlock, status: :forbidden) unless request.post? && codeword.present?

    if ActiveSupport::SecurityUtils.secure_compare(codeword, lockup_codeword)
      cookies.signed[:lockup] = lockup_cookie(codeword_digest)
      redirect_to safe_return_path(@return_to), status: :see_other
    else
      @wrong = true
      render :unlock, status: :forbidden
    end
  end

  private

  # Answered in the shape of a wrong codeword, so the page stays usable
  def render_too_many_attempts
    @return_to = return_to
    @throttled = true
    render :unlock, status: :too_many_requests
  end

  # Each value must be a string, so a hash or an array in its place is left out
  def lockup_params
    @lockup_params ||= params.permit(:return_to, lockup: %i[codeword return_to])
  end

  def return_to
    lockup_params.dig(:lockup, :return_to) || lockup_params[:return_to]
  end

  # Without a codeword there is nothing to unlock, so the page must not answer
  def ensure_lockup_enabled
    redirect_to root_path if lockup_codeword.blank?
  end
end
