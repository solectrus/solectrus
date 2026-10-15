describe Ui::SaveBar::Component, type: :component do
  before { render_inline(described_class.new(form: 'settings_general_form')) }

  it 'saves the named form once a field changes' do
    button = page.find_button('Save', visible: :all, disabled: true)
    aggregate_failures do
      expect(button['type']).to eq('submit')
      expect(button['form']).to eq('settings_general_form')
      expect(button['data-form-dirty-submit']).not_to be_nil
    end
  end

  it 'discards the changes of the named form' do
    button = page.find_button('Discard changes', visible: :all)
    aggregate_failures do
      expect(button['type']).to eq('reset')
      expect(button['form']).to eq('settings_general_form')
    end
  end

  it 'shows on the desktop alone' do
    expect(page).to have_css('.max-lg\:hidden', visible: :all)
  end
end
