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

  # The value of the cookie. It comes from the codeword, so a new codeword
  # locks every browser again. The key comes from secret_key_base, because the
  # signed cookie is readable and a plain hash would let a weak codeword be
  # guessed from it.
  def codeword_digest
    @codeword_digest ||=
      Rails.application.key_generator.generate_key("solectrus-lockup-#{lockup_codeword}", 32).unpack1('H*')
  end
end
