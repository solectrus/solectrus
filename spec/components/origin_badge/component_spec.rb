describe OriginBadge::Component, type: :component do
  before { allow(vc_test_controller).to receive(:admin?).and_return(true) }

  it 'marks an entry of an AI client with an icon and its explanation' do
    render_inline(described_class.new(record: CashFlow.new(origin: :mcp)))

    badge = page.find('span[role="img"]')
    expect(badge['aria-label']).to eq('Entered by AI')
    expect(badge['data-controller']).to eq('tooltip')
    expect(badge).to have_css('svg')
    expect(page.text.strip).to be_empty
  end

  # Each row gets the place, so the marks stand one below the other
  it 'keeps the place empty for an entry of the admin' do
    render_inline(described_class.new(record: CashFlow.new))

    expect(page).to have_css('span[aria-hidden="true"]')
    expect(page).to have_no_css('span[role="img"], svg')
  end

  # Only the admin checks and saves an entry
  it 'gives a visitor without the admin login neither the mark nor its place' do
    allow(vc_test_controller).to receive(:admin?).and_return(false)

    render_inline(described_class.new(record: CashFlow.new(origin: :mcp)))

    expect(page).to have_no_css('span')
  end
end
