describe Ui::GroupHeader::Component, type: :component do
  it 'links its title to the list of the group' do
    render_inline(described_class.new(title: 'March 2026', href: '/list/2026-03'))

    expect(page).to have_css('h3.ui-group-header a[href="/list/2026-03"]', text: 'March 2026')
  end

  it 'shows a plain title without href' do
    render_inline(described_class.new(title: 'Monday'))

    aggregate_failures do
      expect(page).to have_css('h3', text: 'Monday')
      expect(page).to have_no_link
    end
  end
end
