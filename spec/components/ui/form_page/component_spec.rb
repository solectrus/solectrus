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

  context 'when a phone asks for it in a sheet' do
    subject(:component) { described_class.new(title: 'Edit place', subtitle: 'Main Street', form: 'place_form') }

    before do
      vc_test_request.headers['Turbo-Frame'] = 'modal'
      with_request_url('/settings/places/1/edit?form_sheet=1') { render_page }
    end

    it 'renders a tall sheet with a head to close it and to save the form' do
      aggregate_failures do
        expect(page).to have_css('dialog .bottom-sheet-panel.is-tall', text: 'The form')
        expect(page).to have_css('header h2', text: 'Edit place')
        expect(page).to have_css('header p', text: 'Main Street')
        expect(page).to have_css('header button[data-bottom-sheet-close]')
        expect(page).to have_css('header button[type="submit"][form="place_form"]')
      end
    end

    # A save closes the sheet, as the form submits within the modal frame
    it 'holds no frame of the pages of a sheet' do
      expect(page).to have_no_css('turbo-frame#sheet-page')
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
