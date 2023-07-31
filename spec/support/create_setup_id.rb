RSpec.configure do |config|
  config.before :each, :with_setup_id do
    price =
      Price.first ||
        Price.electricity.create!(starts_at: '2020-01-01', value: 0.30)

    price.created_at = Time.zone.at(0)
    price.save!
  end
end
