describe OriginNote::Component, type: :component do
  it 'tells that AI entered the entry' do
    render_inline(described_class.new(record: CashFlow.new(origin: :mcp)))

    expect(page).to have_css('p svg')
    expect(page).to have_text('Entered by AI')
  end

  it 'shows nothing for an entry of the admin' do
    render_inline(described_class.new(record: CashFlow.new))

    expect(page.text).to be_empty
  end
end
