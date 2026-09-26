describe BottomSheet::Component, type: :component do
  it 'renders a dialog without a title' do
    page = render_inline(described_class.new(id: 'probe', data: { turbo_permanent: true }))

    expect(page.css('dialog#probe[data-turbo-permanent]')).to be_present
    expect(page.css('dialog#probe').attr('aria-labelledby')).to be_nil
  end

  it 'labels the dialog with its title' do
    page =
      render_inline(described_class.new(id: 'probe')) do |sheet|
        sheet.with_title { 'Hello' }
        'Content'
      end

    expect(page.css('dialog#probe').attr('aria-labelledby').value).to eq(
      'probe-title',
    )
    expect(page.css('h1#probe-title').text).to eq('Hello')
    expect(page.css('.bottom-sheet-content').text).to eq('Content')
  end

  it 'is wide by default' do
    page = render_inline(described_class.new(id: 'probe'))

    expect(page.css('.bottom-sheet-panel.md\:max-w-3xl')).to be_present
  end

  it 'labels the close button' do
    page = I18n.with_locale(:de) { render_inline(described_class.new(id: 'probe')) }

    expect(page.css('button.bottom-sheet-close').attr('aria-label').value).to eq(
      'Schließen',
    )
  end
end
