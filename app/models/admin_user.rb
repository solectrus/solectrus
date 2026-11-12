class AdminUser
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :username, :string
  attribute :password, :string

  validates :username, comparison: { equal_to: 'admin' }
  validate :verify_password

  # Constant-time check against the configured admin password. The single
  # source of truth for "is this the admin password?", reused wherever the
  # admin credential is the only protection (e.g. the MCP OAuth flow).
  def self.password_correct?(password)
    expected = Rails.configuration.x.admin_password
    expected.present? &&
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected.to_s)
  end

  # The value of the admin cookie. It comes from the password, so a new
  # password ends every session, like the tokens of the MCP connector (see
  # McpOauth.signing_key). The key comes from secret_key_base, because the
  # signed cookie is readable and must not tell the password.
  def self.session_token
    password = Rails.configuration.x.admin_password.presence
    return unless password

    Rails.application.key_generator.generate_key("solectrus-admin-session-#{password}", 32).unpack1('H*')
  end

  # Whether the value of a cookie is the session of the current password
  def self.session?(value)
    token = session_token
    token.present? && value.is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(value, token)
  end

  private

  def verify_password
    errors.add(:password, :invalid) unless AdminUser.password_correct?(password)
  end
end
