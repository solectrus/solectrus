module Lockup
  extend ActiveSupport::Concern

  included do
    before_action :check_for_lockup
  end

  private

  def check_for_lockup
    return unless lockup_codeword

    return if cookies.signed[:lockup] == codeword_digest
    return if migrate_legacy_lockup_cookie

    redirect_to lockup_unlock_path(return_to: request.path)
  end

  # Migrate unsigned cookie from the old lockup gem
  # to a signed cookie. Validates content against current codeword.
  def migrate_legacy_lockup_cookie
    legacy_value = cookies[:lockup]
    return if legacy_value.blank?

    cookies.delete(:lockup)

    return unless ActiveSupport::SecurityUtils.secure_compare(
      legacy_value.to_s.downcase,
      lockup_codeword.to_s.downcase,
    )

    cookies.signed[:lockup] = lockup_cookie(codeword_digest)
    true
  end

  def lockup_cookie(value)
    {
      value:,
      expires: 5.years.from_now,
      httponly: true,
      secure: Rails.env.production?,
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
