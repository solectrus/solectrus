describe Ui::FormPage::Component, type: :component do
  subject(:component) { described_class.new(title: 'Edit price') }

  def render_page
    render_inline(component) { 'The form' }
  end

  context 'when the modal frame asks for it' do
    before do
      vc_test_request.headers['Turbo-Frame'] = 'modal'
      render_page
    end

    it 'renders the content in a sheet' do
      aggregate_failures do
        expect(page).to have_css('turbo-frame#modal dialog', text: 'The form')
        expect(page).to have_text('Edit price')
      end
    end
  end

  context 'when a page asks for it' do
    before { render_page }

    it 'renders title and content' do
      aggregate_failures do
        expect(page).to have_no_css('turbo-frame')
        expect(page).to have_css('h1', text: 'Edit price', visible: :all)
        expect(page).to have_text('The form')
      end
    end
  end
end
