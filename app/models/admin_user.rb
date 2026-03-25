class AdminUser
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :username, :string
  attribute :password, :string

  validates :username, comparison: { equal_to: 'admin' }
  validate :verify_password

  private

  def verify_password
    expected = Rails.configuration.x.admin_password
    unless ActiveSupport::SecurityUtils.secure_compare(
             password.to_s,
             expected.to_s,
           )
      errors.add(:password, :invalid)
    end
  end
end
