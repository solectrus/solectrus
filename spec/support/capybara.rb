RSpec.configure do |config|
  Capybara.enable_aria_label = true

  config.before :each, type: :system do
    driven_by :rack_test
  end

  config.before :each, js: true, type: :system do
    driven_by :selenium, using: :headless_chrome, screen_size: [1200, 800]
  end
end

module SystemSessionHelpers
  def login_as_admin
    allow(Rails.configuration.x).to receive(:admin_password).and_return(
      't0ps3cr3t',
    )

    visit new_session_path
    fill_in :admin_user_password, with: 't0ps3cr3t'
    click_on I18n.t('login.submit')

    expect(page).to have_link(nil, href: '/logout')
  end

  def logout
    Capybara.reset_sessions!
  end
end

module RequestSessionHelpers
  def login_as_admin
    allow(Rails.configuration.x).to receive(:admin_password).and_return(
      't0ps3cr3t',
    )

    post '/login', params: { admin_user: { password: 't0ps3cr3t' } }
    expect(response).to redirect_to(root_path)
  end

  def logout
    delete '/logout'
    expect(response).to redirect_to(root_path)
  end
end

RSpec.configure { |config| config.include SystemSessionHelpers, type: :system }
RSpec.configure do |config|
  config.include RequestSessionHelpers, type: :request
end
