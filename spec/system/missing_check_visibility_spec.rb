# Safari has Element#checkVisibility only since 17.4, but the app supports
# Safari from 16.4. The controllers that call it must work without it.
describe 'Missing checkVisibility' do
  before { driven_by :playwright_mobile }

  it 'moves the marking of the timeframe tabs' do
    errors =
      without_check_visibility('/house_power/all') do |old|
        old.wait_for_selector('#stats-all')
        old.click('nav[aria-label="Tabs"]:visible > a:has(span:text-is("Jahr"))')
        old.wait_for_url(%r{/house_power/\d{4}\z})
      end

    expect(errors).to be_empty
  end

  private

  # Open the path in a page of its own, so the missing method does not leak
  # into the next example: the browser page is reused between examples.
  # Returns the errors of the page. Stimulus catches the errors of a
  # controller and logs them, so the console counts as well.
  def without_check_visibility(path)
    errors = []

    page.driver.with_playwright_page do |pw|
      old = pw.context.new_page
      old.add_init_script(script: 'delete Element.prototype.checkVisibility;')
      old.on('pageerror', ->(error) { errors << error.message })
      old.on('console', ->(message) { errors << message.text if message.type == 'error' })

      old.goto("#{Capybara.current_session.server.base_url}#{path}")
      yield old
      errors
    ensure
      old&.close
    end
  end
end
