describe Insights::Total::Component, type: :component do
  let(:total) { Sensor::Value::Component.new(10_106_000, :inverter_power, context: :total, precision: 3) }

  def row(**) = render_inline(described_class.new(total:, **)).text.squish

  it 'renders the total as a row' do
    expect(row).to match(/\ATotal\s*10.106 MWh\z/)
  end

  it 'marks the total of a running period' do
    expect(row(running: true)).to match(/\ASo far\s*10.106 MWh\z/)
  end

  it 'names an average' do
    expect(row(average: true)).to match(/\AAverage\s*10.106 MWh\z/)
  end
end
