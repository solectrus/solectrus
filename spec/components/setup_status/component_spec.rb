describe SetupStatus::Component, type: :component do
  subject(:component) do
    described_class.new(
      registration_status:,
      subscription_plan:,
      prompt:,
      admin:,
    )
  end

  let(:subscription_plan) { nil }
  let(:admin) { false }
  let(:prompt) { false }

  before { render_inline(component) }

  context 'when registration status is complete and prompt' do
    let(:registration_status) { 'complete' }
    let(:prompt) { true }

    it 'renders icon' do
      expect(page).to have_css('div i.fa-circle-exclamation')
    end
  end

  context 'when registration status is complete and plan is sponsor' do
    let(:registration_status) { 'complete' }
    let(:subscription_plan) { 'sponsoring' }

    it 'renders nothing' do
      expect(page).to have_no_css('div')
    end
  end

  context 'when registration status is unknown' do
    let(:registration_status) { 'unknown' }

    it 'renders icon' do
      expect(page).to have_css('div i.fa-circle-exclamation')
    end
  end

  context 'when registration status is pending' do
    let(:registration_status) { 'pending' }

    it 'renders nothing (because there is a banner)' do
      expect(page).to have_no_css('div')
    end
  end

  context 'when registration status is unregistered' do
    let(:registration_status) { 'unregistered' }

    it 'renders nothing (because there is a banner)' do
      expect(page).to have_no_css('div')
    end
  end
end
