describe RegistrationStatus::Component, type: :component do
  subject(:component) do
    described_class.new(
      registration_status: registration_status.inquiry,
      admin:,
    )
  end

  let(:admin) { false }

  before { render_inline(component) }

  context 'when registration status is complete' do
    let(:registration_status) { 'complete' }

    it 'renders nothing' do
      expect(page).to have_no_css('div')
    end
  end

  context 'when registration status is unknown' do
    let(:registration_status) { 'unknown' }

    it 'renders red icon' do
      expect(page).to have_css('div i.text-red-300')
    end
  end

  context 'when registration status is pending' do
    let(:registration_status) { 'pending' }

    it 'renders red icon' do
      expect(page).to have_css('div i.text-red-400')
    end
  end

  context 'when registration status is unregistered' do
    let(:registration_status) { 'unregistered' }

    it 'renders red icon' do
      expect(page).to have_css('div i.text-red-500')
    end
  end

  context 'when registration status is skipped' do
    let(:registration_status) { 'skipped' }

    it 'renders red icon' do
      expect(page).to have_css('div i.text-red-500')
    end
  end
end
