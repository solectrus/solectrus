RSpec.configure do |config|
  config.before :each, :with_setup_id do |example|
    Rails.application.load_seed

    setup_id = example.metadata[:with_setup_id]
    Price.first.update! created_at: Time.zone.at(setup_id)
  end
end
