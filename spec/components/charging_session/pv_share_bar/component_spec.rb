describe ChargingSession::PvShareBar::Component, type: :component do
  it 'splits the bar into PV and grid' do
    result = render_inline(described_class.new(percent: 75))

    expect(result.css('.bg-sensor-pv').first['style']).to eq('width: 75%')
    expect(result.css('.bg-sensor-grid').first['style']).to eq('width: 25%')
    expect(result.text).to include('75%')
  end

  it 'says what it shows' do
    result = render_inline(described_class.new(percent: 75))

    expect(result.css('.sr-only').text.strip).to eq('75% from PV')
  end

  it 'leaves out the empty part' do
    result = render_inline(described_class.new(percent: 100))

    expect(result.css('.bg-sensor-grid')).to be_empty
  end
end
