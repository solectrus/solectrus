describe Insights::Row::Component, type: :component do
  it 'renders label, detail and value' do
    page =
      render_inline(described_class.new(label: 'Minimum', detail: '13.09.2026')) do
        '7.7 kWh'
      end

    expect(page.css('div.insights-row').text).to include('Minimum', '7.7 kWh')
    expect(page.css('.tooltip-detail').text).to eq('13.09.2026')
    expect(page.css('a')).to be_empty
  end

  it 'leads to its URL with a chevron' do
    page = render_inline(described_class.new(label: 'Maximum', url: '/day')) { '12 kWh' }

    expect(page.css('a.insights-row-link').attr('href').value).to eq('/day')
    expect(page.css('.insights-row-chevron')).to be_present
    expect(page.css('.tooltip-detail')).to be_empty
  end

  it 'shows a short note beside the label' do
    page = render_inline(described_class.new(label: 'String 3', note: '49 %')) { '5.8 MWh' }

    expect(page.css('.insights-row-label-note').text).to eq('49 %')
    expect(page.css('.insights-row-label-note-long')).to be_empty
  end

  it 'lets a long note take a line of its own' do
    page = render_inline(described_class.new(label: 'Previous month', note: 'Aug 1-27, 2026')) { '-22 %' }

    expect(page.css('.insights-row-label-note-long').text).to eq('Aug 1-27, 2026')
  end

  it 'is a button with an action' do
    page = render_inline(described_class.new(label: 'Heatmap', action: 'insights--component#push')) { '' }

    expect(page.css('button.insights-row-link').attr('data-action').value).to eq('insights--component#push')
    expect(page.css('svg.insights-row-chevron')).to be_present
  end
end
