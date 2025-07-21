module SystemHelpers
  def login_as_admin
    visit '/login'
    fill_in 'admin_user_password', with: 'secret'
    click_on 'Anmelden'
    expect(page).to have_no_current_path('/login')
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
end

RSpec.configure { |config| config.include SystemHelpers, type: :system }
