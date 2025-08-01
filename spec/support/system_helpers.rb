module SystemHelpers
  def login_as_admin
    visit '/login'

    # Optimized cookie-based login: cache once, reuse for subsequent tests
    if cached_admin_cookie
      # Fast path: set cookie directly via JavaScript
      page.execute_script(
        "document.cookie = 'admin=#{cached_admin_cookie}; path=/';",
      )
    else
      # First time: perform normal login and cache cookie
      fill_in 'admin_user_password', with: Rails.configuration.x.admin_password
      click_on 'Anmelden'
      expect(page).to have_no_current_path('/login')

      # Cache cookie value for subsequent tests
      RSpec.configuration.admin_cookie_value =
        page.driver.with_playwright_page do |pw|
          pw.context.cookies.find { it['name'] == 'admin' }&.dig('value')
        end
    end
  end

  # Turbo-safe navigation helper for flaky DOM updates
  def turbo_safe_click(aria_label)
    retries = 0
    begin
      find("a[aria-label=\"#{aria_label}\"]", visible: true).click
    rescue Playwright::Error => e
      if e.message.exclude?('Element is not attached to the DOM') ||
           retries >= 3
        raise
      end

      retries += 1
      sleep 0.1
      retry
    end
  end

  private

  def cached_admin_cookie
    return unless RSpec.configuration.respond_to?(:admin_cookie_value)

    RSpec.configuration.admin_cookie_value
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  # Add custom configuration for caching admin cookie
  config.add_setting :admin_cookie_value

  # Clear cached cookie before each test suite run
  config.before(:suite) { config.admin_cookie_value = nil }
end
