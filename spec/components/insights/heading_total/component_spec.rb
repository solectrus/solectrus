describe Insights::HeadingTotal::Component, type: :component do
  let(:total) { SensorValue::Component.new(10_106_000, :inverter_power, context: :total, precision: 3) }

  it 'renders the total' do
    page = render_inline(described_class.new(total:))

    expect(page.text.squish).to eq('10.106 MWh')
  end

  it 'marks the total of a running period' do
    page = render_inline(described_class.new(total:, running: true))

    expect(page.text.squish).to start_with('so far')
    expect(page.text.squish).to include('10.106 MWh')
  end
end
