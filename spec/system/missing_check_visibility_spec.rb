# Safari has Element#checkVisibility only since 17.4, but the app supports
# Safari from 16.4. The code that calls it must work without it.
describe 'Missing checkVisibility' do
  context 'with a phone' do
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
  end

  # The card glides on a desktop only. Top 10 still loads its frame when
  # Turbo renders it, so the glide looks for the frames that load.
  context 'with a desktop' do
    it 'completes the visit of a page that loads a frame' do
      errors =
        without_check_visibility('/house_power/2022') do |old|
          old.click('a[href^="/top10"]:visible')
          old.wait_for_url(%r{/top10/})
          old.wait_for_selector('html:not([aria-busy])', state: 'attached', timeout: 10_000)
        end

      expect(errors).to be_empty
    end
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
    rescue StandardError
      save_failure(old, errors) if old
      raise
    ensure
      old&.close
    end
  end

  # The screenshot of Rails shows the page of Capybara, which stays blank here.
  # Save what the page of its own shows instead, where CI uploads it.
  def save_failure(old, errors)
    base = Capybara.save_path.join('missing_check_visibility')
    FileUtils.mkdir_p(Capybara.save_path)
    old.screenshot(path: "#{base}.png")
    File.write("#{base}.html", old.content)
    warn "URL: #{old.url}", "Errors: #{errors.inspect}"
  rescue StandardError => e
    warn "Saving the failure failed: #{e.message}"
  end
end
