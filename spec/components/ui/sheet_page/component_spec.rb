describe Ui::SheetPage::Component, type: :component do
  before { vc_test_request.headers['Turbo-Frame'] = 'modal' }

  it 'renders the first page in the frame of the sheet, with a button that closes it' do
    render_inline(described_class.new(title: 'Charging')) do |page|
      page.with_action(href: '/new', icon: 'plus', label: 'New')
      'The list'
    end

    aggregate_failures do
      expect(page).to have_css('dialog turbo-frame#sheet-page', text: 'The list', visible: :all)
      expect(page).to have_css('header h2', text: 'Charging', visible: :all)
      expect(page).to have_css('header button[data-bottom-sheet-close]', visible: :all)
      expect(page).to have_css('header a[href="/new"][aria-label="New"]', visible: :all)
    end
  end

  it 'renders a page one level down with the way back and the save button' do
    render_inline(described_class.new(title: 'Edit', back_href: '/list', back_label: 'Charging', frame: false)) do |page|
      page.with_save(form: 'session_form')
      'The form'
    end

    aggregate_failures do
      expect(page).to have_no_css('turbo-frame#sheet-page', visible: :all)
      expect(page).to have_css('header[data-sheet-depth="1"] a[href="/list"][aria-label="Charging"]', visible: :all)
      expect(page).to have_css('header button[type="submit"][form="session_form"][disabled][data-form-dirty-submit]', visible: :all)
    end
  end
end
