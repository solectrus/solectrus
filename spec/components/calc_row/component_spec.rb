describe CalcRow::Component, type: :component do
  it 'puts the operator in front of the label' do
    page = render_inline(described_class.new(label: 'Feed-in', operator: :minus)) { '5 kWh' }

    expect(page.css('.label-value-row > dt').text).to eq("−\u00A0Feed-in")
    expect(page.css('.label-value-row > dd.tooltip-number').text).to eq('5 kWh')
    expect(page.css('.tooltip-result')).to be_empty
  end

  it 'marks a row with "=" as a result' do
    page = render_inline(described_class.new(label: 'Sum', operator: :equals, total: true))

    expect(page.css('.label-value-row.tooltip-result.tooltip-total')).to be_present
  end

  it 'renders a row without an operator' do
    page = render_inline(described_class.new(label: 'Import'))

    expect(page.css('dt').text).to eq('Import')
  end
end
