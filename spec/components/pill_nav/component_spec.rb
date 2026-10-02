describe PillNav::Component, type: :component do
  let(:items) do
    [
      described_class::Item.new(label: 'All', href: '/all', current: true, color: nil),
      described_class::Item.new(label: 'Car', href: '/car', current: false, color: '#ff0000'),
    ]
  end

  it 'links to each choice and marks the current one' do
    render_inline(described_class.new(label: 'Car', items:))

    expect(page).to have_css('nav[aria-label="Car"]')
    expect(page).to have_link 'All', href: '/all'
    expect(page).to have_css('a[aria-current="page"]', text: 'All')
    expect(page).to have_no_css('a[aria-current="page"]', text: 'Car')
  end

  it 'shows the color of a choice as a dot' do
    render_inline(described_class.new(label: 'Car', items:))

    expect(page).to have_css('a[href="/car"] span[style="background-color: #ff0000"]')
    expect(page).to have_no_css('a[href="/all"] span')
  end
end
