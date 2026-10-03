describe Nav::TitleBar::Component, type: :component do
  it 'renders the title without a back button on the top level' do
    html = render_inline(described_class.new(title: 'Settings'))

    expect(html.css('h1').text).to eq('Settings')
    expect(html.css('a')).to be_empty
  end

  it 'renders a back button to the parent' do
    html =
      render_inline(
        described_class.new(
          title: 'General',
          back_href: '/settings',
          back_label: 'Settings',
        ),
      )

    link = html.css('a').first
    expect(link['href']).to eq('/settings')
    expect(link['aria-label']).to eq('Settings')
  end
end
