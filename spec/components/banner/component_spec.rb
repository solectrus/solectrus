describe Banner::Component, type: :component do
  subject(:component) { described_class.new(registration_status:, admin:) }

  let(:registration_status) { 'unregistered' }

  context 'when admin' do
    let(:admin) { true }

    it 'renders the banner' do
      result = render_inline(component)

      expect(result.to_html).to include('Please proceed with the registration')
      expect(result.to_html).to include('Register now')
    end
  end

  context 'when not admin' do
    let(:admin) { false }

    it 'renders the banner' do
      result = render_inline(component)

      expect(result.to_html).to include(I18n.t('layout.login'))
    end
  end
end
