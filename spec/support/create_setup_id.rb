RSpec.configure do |config|
  config.before :each, :with_setup_id do |example|
    setup_id = example.metadata[:with_setup_id]
    Setting.setup_id = setup_id
    Setting.setup_token = SecureRandom.alphanumeric(16)
  end
end
