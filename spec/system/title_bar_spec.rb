describe 'Title bar (mobile)' do
  before { driven_by :playwright_mobile }

  # Headless Chromium keeps every page visible, so fake the state of a tab in
  # the background and raise the event a browser fires when it changes.
  def fake_hidden(hidden)
    page.execute_script(<<~JS, hidden)
      const hidden = arguments[0];
      Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
      Object.defineProperty(document, 'visibilityState', {
        configurable: true,
        get: () => (hidden ? 'hidden' : 'visible'),
      });
      document.dispatchEvent(new Event('visibilitychange'));
    JS
  end

  def view_transition_tags
    page.evaluate_script(
      'document.head.querySelectorAll(\'meta[name="view-transition"]\').length',
    )
  end

  # The browser aborts a view transition in a hidden document, so a page that
  # renders there must not ask for one.
  it 'asks for no view transition while the document is hidden' do
    visit '/more'
    expect(view_transition_tags).to eq(1)

    fake_hidden(true)
    expect(view_transition_tags).to eq(0)

    # A reload in the background brings the tag back with its head
    page.execute_script(<<~JS)
      addEventListener('turbo:load', () => (document.body.dataset.reloaded = ''), { once: true });
      Turbo.visit(location.href, { action: 'replace' });
    JS
    expect(page).to have_css('body[data-reloaded]')
    expect(view_transition_tags).to eq(0)

    fake_hidden(false)
    expect(view_transition_tags).to eq(1)
  end
end
