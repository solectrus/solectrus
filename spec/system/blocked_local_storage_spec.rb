# A browser can deny access to localStorage, for example Safari with blocked
# website data. The controllers that read or write it must work anyway.
describe 'Blocked localStorage' do
  it 'connects the theme and palette selectors' do
    allow(ApplicationPolicy).to receive(:themes?).and_return(true)

    checked, errors =
      with_blocked_local_storage('/') do |blocked|
        blocked.evaluate(<<~JS)
          [
            "[data-theme-selector--component-target='inputAuto']",
            "[data-color-palette-selector--component-target='inputStandard']",
          ].every((selector) =>
            [...document.querySelectorAll(selector)].every((input) => input.checked),
          )
        JS
      end

    expect(errors).to be_empty
    expect(checked).to be(true)
  end

  it 'toggles the breakdown view' do
    table_visible, errors =
      with_blocked_local_storage('/house/house_power/day') do |blocked|
        blocked.click('button[aria-label="Ansicht wechseln"]')
        blocked.wait_for_selector(
          '[data-view-toggle-target="table"]:not(.hidden)',
          timeout: 2000,
        )
        true
      rescue Playwright::TimeoutError
        false
      end

    expect(errors).to be_empty
    expect(table_visible).to be(true)
  end

  private

  # Open the path in a page of its own, so the blocked localStorage does not
  # leak into the next example: the browser page is reused between examples.
  # Returns the result of the block and the errors the page raised.
  def with_blocked_local_storage(path)
    errors = []

    page.driver.with_playwright_page do |pw|
      blocked = pw.context.new_page
      blocked.add_init_script(script: <<~JS)
        Object.defineProperty(window, 'localStorage', {
          get() { throw new DOMException('Access denied', 'SecurityError') },
        });
      JS
      blocked.on('pageerror', ->(error) { errors << error.message })

      # goto waits for the load event, and Stimulus connects before it
      blocked.goto("#{Capybara.current_session.server.base_url}#{path}")

      [yield(blocked), errors]
    ensure
      blocked&.close
    end
  end
end
