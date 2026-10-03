describe TooltipHeader::Component, type: :component do
  it 'puts the value below the title' do
    page = render_inline(described_class.new(title: 'Autarky')) { '81 %' }

    expect(page.css('.tooltip-header .tooltip-title').text.strip).to eq(
      'Autarky',
    )
    expect(page.css('.tooltip-heading').text).to include('81 %')
  end

  it 'renders the icon beside the heading' do
    page =
      render_inline(described_class.new(title: 'Power')) do |header|
        header.with_icon { '<svg class="tooltip-icon"></svg>'.html_safe }
      end

    expect(page.css('.tooltip-header > svg.tooltip-icon + .tooltip-heading')).to be_present
  end

  it 'renders a total as the larger main value' do
    page = render_inline(described_class.new(title: 'Yield', sensor_name: :inverter_power, value: 12_345, total: true))

    expect(page.css('.tooltip-heading > .tooltip-value.tooltip-value-lg')).to be_present
  end

  it 'renders a rate as the main value' do
    page = render_inline(described_class.new(title: 'Power', sensor_name: :inverter_power, value: 1_234))

    expect(page.css('.tooltip-heading > .tooltip-value')).to be_present
    expect(page.css('.tooltip-value-lg')).to be_empty
  end

  it 'marks a header that only the sheet shows' do
    page = render_inline(described_class.new(title: 'Autarky', sheet_only: true))

    expect(page.css('.tooltip-header.tooltip-header-sheet-only')).to be_present
  end

  it 'shows a header everywhere by default' do
    page = render_inline(described_class.new(title: 'Autarky'))

    expect(page.css('.tooltip-header-sheet-only')).to be_empty
  end
end
