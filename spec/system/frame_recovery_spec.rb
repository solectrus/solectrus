# A frame whose request dies keeps its spinner: Turbo marks a frame `complete`
# only after a successful render, and never retries on its own. The recovery in
# setupStimulus reloads such a frame, which is what these examples check.
describe 'Frame recovery' do
  it 'reloads a chart frame whose request was refused' do
    visit '/heatpump_power/2022-06-21'
    expect(page).to have_css('canvas')

    refuse_next('**/charts/**')

    visit '/heatpump_power/2022-06-21'

    expect(page).to have_css('canvas')
  ensure
    unroute('**/charts/**')
  end

  # The full-screen spinner: a day without a summary is built by SummaryBuilder
  # first, in a frame of its own. A dead connection answers that request with
  # nothing at all - no response and no error either - so the frame just stays
  # busy and nothing reports it. Returning to the tab is what cuts it loose.
  it 'reloads a stuck summary frame when the tab comes back' do
    Summary.where(date: '2022-06-10').delete_all
    never_answer('**/summaries/**')

    visit '/heatpump_power/2022-06-10'

    # The page hangs in the SummaryBuilder branch, which has no chart
    expect(page).to have_css('.timeframe-day')
    expect(page).to have_no_css("[data-controller*='stats-with-chart--component']")

    return_to_tab

    # The summary is built now, so the page reaches its normal branch
    expect(page).to have_css("[data-controller*='stats-with-chart--component']")
  ensure
    unroute('**/summaries/**')
  end

  private

  # Let the next matching request fail the way a dropped connection does. Every
  # request after it passes through untouched.
  def refuse_next(pattern)
    refusal = ->(route, _req) { route.abort(errorCode: 'connectionfailed') }

    page.driver.with_playwright_page do |pw|
      pw.route(pattern, refusal, times: 1)
    end
  end

  # Leave the first request pending for good - a request into a socket nobody
  # answers - and let every later one through. A handler that never continues,
  # fulfills or aborts does not consume a `times` budget, so it counts itself.
  def never_answer(pattern)
    seen = 0
    silence = ->(route, _req) { route.continue if (seen += 1) > 1 }

    page.driver.with_playwright_page { |pw| pw.route(pattern, silence) }
  end

  # Headless Chromium keeps every page visible, even when another tab is brought
  # to the front, so raise the event a browser fires when a tab comes back.
  def return_to_tab
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
  end

  # A route outlives its example, because the browser page is reused.
  def unroute(pattern)
    page.driver.with_playwright_page { |pw| pw.unroute(pattern) }
  end
end
