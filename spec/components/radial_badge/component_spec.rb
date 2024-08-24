describe RadialBadge::Component, type: :component do
  subject(:component) { described_class.new(percent:, title: 'Test') }

  context 'when percent is 0' do
    before { render_inline(component) }

    let(:percent) { 0 }

    it 'renders component' do
      expect(page).to have_css '.badge.border-transparent', text: '0%'
    end
  end

  context 'when percent is low' do
    before { render_inline(component) }

    let(:percent) { 10 }

    it 'renders component' do
      expect(page).to have_css '.badge.border-red-200', text: '10%'
    end
  end

  context 'when percent is medium' do
    before { render_inline(component) }

    let(:percent) { 50 }

    it 'renders component' do
      expect(page).to have_css '.badge.border-orange-200', text: '50%'
    end
  end

  context 'when percent is high' do
    before { render_inline(component) }

    let(:percent) { 80 }

    it 'renders component' do
      expect(page).to have_css '.badge.border-green-200', text: '80%'
    end
  end

  context 'without percent' do
    before { render_inline(component) }

    let(:percent) { nil }

    it 'renders component' do
      expect(page).to have_css '.badge.border-slate-200'
    end
  end

  context 'when percent is invalid' do
    let(:percent) { -10 }

    it 'fails' do
      expect { render_inline(component) }.to raise_error ArgumentError
    end
  end
end
