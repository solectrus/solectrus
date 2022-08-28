class AdminUser
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :username, :string
  attribute :password, :string

  validates :password,
            comparison: {
              equal_to: proc { Rails.configuration.x.admin_password },
              message: :invalid,
            }
end
