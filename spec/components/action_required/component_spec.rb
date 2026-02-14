describe ActionRequired::Component, type: :component do
  subject(:component) do
    described_class.new(registration_status:, admin:)
  end

  let(:admin) { false }

  before { render_inline(component) }

  context 'when registration status is complete' do
    let(:registration_status) { 'complete' }

    it 'renders yellow icon' do
      expect(page).to have_css('div i.fa-circle-exclamation.text-amber-300')
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
  end
end
