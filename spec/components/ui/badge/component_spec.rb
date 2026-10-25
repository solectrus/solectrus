describe Ui::Badge::Component, type: :component do
  it 'renders the label in the color' do
    render_inline(described_class.new(color: :teal).with_content('Investment'))

    aggregate_failures do
      expect(page).to have_css('span.bg-teal-100', text: 'Investment')
      expect(page).to have_no_link
    end
  end

  it 'adds the x that removes it from the filter' do
    render_inline(described_class.new(color: :red, remove_path: '/list').with_content('Costs'))

    expect(page).to have_css('span.bg-red-100 a[href="/list"][aria-label="Remove from filter"]')
  end
end
