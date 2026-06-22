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

  private

  def verify_password
    errors.add(:password, :invalid) unless AdminUser.password_correct?(password)
  end
end
