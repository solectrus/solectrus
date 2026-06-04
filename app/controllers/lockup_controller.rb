class LockupController < ApplicationController
  skip_before_action :check_for_lockup
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

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

  def safe_return_path(path)
    return '/' if path.blank?

    # Only allow relative paths (no scheme, no host) starting with a single
    # forward slash. This blocks open redirects, including protocol-relative
    # URLs like "//evil.com" and backslash tricks like "/\evil.com".
    return '/' unless path.start_with?('/')
    return '/' if path.start_with?('//', '/\\')

    uri = URI.parse(path)
    return '/' if uri.scheme || uri.host

    uri.to_s
  rescue URI::InvalidURIError
    '/'
  end
end
