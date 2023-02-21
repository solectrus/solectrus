Capybara.default_normalize_ws = true

RSpec.configure do |config|
  Capybara.enable_aria_label = true

  config.before :each, type: :system do
    driven_by :rack_test
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

RSpec.configure do |config|
  config.include RequestSessionHelpers, type: :request
end
