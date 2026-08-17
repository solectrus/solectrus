describe ActionRequired::Component, type: :component do
  subject(:component) { described_class.new(registration_status:) }

  before { render_inline(component) }

  context 'when registration status is complete' do
    let(:registration_status) { 'complete' }

    it 'renders yellow icon' do
      expect(page).to have_css('div i.fa-circle-exclamation.text-amber-300')
    end

    # Not the reason a single feature is locked - this icon has one message.
    it 'names the missing sponsorship' do
      expect(page).to have_css("div[title='Sponsorship required!']")
    end

    it 'leads where the text points' do
      expect(page).to have_link(href: '/sponsoring')
    end

    context 'when the free month is still unused' do
      before do
        allow(PremiumStatus).to receive(:trial_available?).and_return(true)
        render_inline(component)
      end

      it 'still leads to the sponsoring page, which offers the month itself' do
        expect(page).to have_link(href: '/sponsoring')
      end
    end
  end

  context 'when registration status is unknown' do
    let(:registration_status) { 'unknown' }

    it 'renders red icon' do
      expect(page).to have_css('div i.fa-circle-exclamation.text-red-300')
    end
  end

  context 'when registration status is pending' do
    let(:registration_status) { 'pending' }

    it 'renders yellow icon' do
      expect(page).to have_css('div i.fa-circle-exclamation.text-amber-300')
    end
  end

  context 'when registration status is unregistered' do
    let(:registration_status) { 'unregistered' }

    it 'renders yellow icon' do
      expect(page).to have_css('div i.fa-circle-exclamation.text-amber-300')
    end

    # Only an admin can register, so only an admin is sent there.
    context 'with an admin' do
      subject(:component) do
        allow(vc_test_controller).to receive(:admin?).and_return(true)
        described_class.new(registration_status:)
      end

      it 'leads to the registration' do
        expect(page).to have_link(href: '/registration')
      end

      it 'names the registration alone, because they can do it' do
        expect(page).to have_css("div[title='Registration required']")
      end
    end

    # The registration page would turn them away without a word. The sponsoring
    # page explains the situation and carries the login button.
    context 'without an admin session' do
      it 'leads to the sponsoring page' do
        expect(page).to have_no_link(href: '/registration')
        expect(page).to have_link(href: '/sponsoring')
      end

      # That page speaks about the sponsoring, so the text must name the step
      # that is really behind the click.
      it 'names the login' do
        expect(page).to have_css(
          "div[title='Registration required – please log in as admin']",
        )
      end
    end
  end
end
