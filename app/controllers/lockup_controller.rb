class LockupController < ApplicationController
  include SafeReturnPath

  skip_before_action :check_for_lockup
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  before_action :ensure_lockup_enabled

  layout 'blank'

  def unlock
    @return_to = params.dig(:lockup, :return_to) || params[:return_to]

    return unless request.post? && params.dig(:lockup, :codeword).present?

    codeword = params[:lockup][:codeword].to_s

    if ActiveSupport::SecurityUtils.secure_compare(codeword, lockup_codeword)
      cookies.signed[:lockup] = lockup_cookie(codeword_digest)
      redirect_to safe_return_path(@return_to)
    else
      @wrong = true
      render :unlock, status: :unprocessable_content
    end
  end

  private

  # Without a codeword there is nothing to unlock, so the page must not answer
  def ensure_lockup_enabled
    redirect_to root_path if lockup_codeword.blank?
  end
end
