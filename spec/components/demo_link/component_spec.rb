describe DemoLink::Component, type: :component do
  subject(:component) { described_class.new(url:, feature:) }

  let(:url) { { controller: 'house/home', action: 'index' } }
  let(:feature) { 'custom_consumer' }

  it 'renders the buttons' do
    render_inline(component)

    expect(page).to have_link 'Learn more about sponsoring', href: '/sponsoring'
    expect(page).to have_link 'Demo', href: %r{\Ahttps://demo\.solectrus\.de/house\?}
  end

  it 'names the reason in the badge' do
    render_inline(component)

    expect(page).to have_text 'Exclusively for sponsors'
  end

  # The demo counts its visitors with Plausible, so a teaser visit has to be
  # tellable from every other way in. utm_content names the feature.
  it 'tags the demo link for the analytics of the demo' do
    render_inline(component)

    href = page.find_link('Demo')[:href]
    query = Rack::Utils.parse_query(URI.parse(href).query)

    expect(query).to include(
      'utm_source' => 'solectrus-app',
      'utm_medium' => 'referral',
      'utm_campaign' => 'feature-teaser',
      'utm_content' => 'custom_consumer',
    )
  end

  context 'when the free month is still unused' do
    before do
      allow(PremiumStatus).to receive(:trial_available?).and_return(true)
    end

    # Whoever cannot start the month can still tell the person who can, so the
    # offer does not depend on the admin session.
    [true, false].each do |admin|
      it "names the offer #{admin ? 'to an admin' : 'to everyone else'}" do
        allow(vc_test_controller).to receive(:admin?).and_return(admin)
        render_inline(component)

        expect(page).to have_text 'By the way, you can try the full feature set free for one month.'
      end
    end

    # A button of its own would need a second target, and the registration
    # turns away everyone without the admin session.
    it 'leaves the page with one call to action' do
      render_inline(component)

      expect(page).to have_link 'Learn more about sponsoring', href: '/sponsoring'
      expect(page).to have_no_link href: '/registration'
    end
  end

  context 'when the free month is used up' do
    it 'names no offer' do
      render_inline(component)

      expect(page).to have_no_text 'By the way, you can try the full feature set free for one month.'
    end
  end
end
