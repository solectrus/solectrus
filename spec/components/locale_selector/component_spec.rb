describe LocaleSelector::Component, type: :component do
  subject(:component) { described_class.new }

  # A redirect back to the same URL triggers a Turbo morph refresh that
  # resets lazy turbo-frames (chart/stats) to their spinner without
  # reloading them. Disabling Turbo forces a full reload and avoids that.
  it 'renders the switcher as a non-Turbo form' do
    render_inline(component)

    form = page.find('form[action="/locale"]')
    expect(form['data-turbo']).to eq('false')
  end
end
