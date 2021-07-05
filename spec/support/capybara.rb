RSpec.configure do |config|
  config.before :each, type: :system do
    driven_by :rack_test
  end

  config.before :each, type: :system, js: true do
    driven_by :selenium, using: :headless_chrome, screen_size: [1200, 800]
  end

  config.after :each, type: :system, js: true do
    messages =
      page
        .driver
        .browser
        .manage
        .logs
        .get(:browser)
        .filter_map { |log| "[#{log.level}] #{log.message}" }

    expect(messages.length).to be_zero, messages.join("\n")
  end
end
