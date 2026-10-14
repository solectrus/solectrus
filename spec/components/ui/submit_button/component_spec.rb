describe Ui::SubmitButton::Component, type: :component do
  it 'renders one disabled button with its label and a check mark, on the desktop only' do
    render_inline(described_class.new)

    button = page.find('.max-lg\:hidden button[type="submit"][data-form-dirty-submit][disabled]')
    aggregate_failures do
      expect(button).to have_text('Save', exact: true)
      expect(button).to have_css('.fa-check')
      expect(page).to have_no_button('Delete')
    end
  end

  it 'renders a label of its own' do
    render_inline(described_class.new(label: 'Accept'))

    expect(page).to have_button('Accept', disabled: true)
  end

  it 'renders a trash icon on the desktop and a red line on a phone, both submit the form as a DELETE' do
    render_inline(described_class.new(delete_path: '/prices/1'))

    buttons = page.all('button[formaction="/prices/1"]')
    aggregate_failures do
      expect(buttons.pluck('formmethod')).to eq(%w[delete delete])
      expect(buttons.pluck('data-turbo-confirm')).to all(be_present)
      expect(buttons.first).to have_css('.fa-trash')
      expect(buttons.first['title']).to eq('Delete')
      expect(buttons.first.text).to be_empty
      expect(buttons.last).to have_text('Delete')
      expect(page).to have_css('.lg\:hidden button[formaction="/prices/1"].w-full')
    end
  end

  it 'puts the save button first, so Enter in a field saves and does not delete' do
    render_inline(described_class.new(delete_path: '/prices/1'))

    expect(page.first('button[type="submit"]')['data-form-dirty-submit']).not_to be_nil
  end

  it 'submits another way with its own label and question' do
    render_inline(described_class.new(delete_path: '/sessions/1/dismiss', removal: { method: :patch, label: 'Dismiss', confirm: 'Sure?', icon: 'xmark' }))

    buttons = page.all('button[formaction="/sessions/1/dismiss"]')
    aggregate_failures do
      expect(buttons.pluck('formmethod')).to eq(%w[patch patch])
      expect(buttons.pluck('data-turbo-confirm')).to eq(%w[Sure? Sure?])
      expect(buttons.first['aria-label']).to eq('Dismiss')
      expect(buttons.last).to have_text('Dismiss')
      expect(buttons.first).to have_css('.fa-xmark')
    end
  end
end
