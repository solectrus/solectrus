module Lockup
  extend ActiveSupport::Concern

  included do
    before_action :check_for_lockup
  end

  private

  def check_for_lockup
    return unless lockup_codeword

    return if cookies.signed[:lockup] == codeword_digest

    redirect_to lockup_unlock_path(return_to: request.path)
  end

  def lockup_cookie(value)
    {
      value:,
      expires: 5.years.from_now,
      httponly: true,
      secure: request.ssl?,
      same_site: :lax,
    }
  end

  def lockup_codeword
    Rails.configuration.x.lockup_codeword
  end

  def codeword_digest
    @codeword_digest ||= Digest::SHA256.hexdigest(lockup_codeword)
  end
end
