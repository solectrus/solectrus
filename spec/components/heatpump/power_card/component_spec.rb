describe Heatpump::PowerCard::Component, type: :component do
  subject(:component) do
    described_class.new(
      data: Sensor::Data::Single.new(raw_data, timeframe: Timeframe.day),
      timeframe: Timeframe.day,
      css_class: nil,
    )
  end

  context 'when the parts add up to the total' do
    let(:raw_data) do
      { heatpump_power: 5_000, heatpump_power_pv: 1_234, heatpump_power_grid: 3_766 }
    end

    it 'rounds them to add up' do
      expect(component.tooltip_values.parts.sum).to eq(component.tooltip_values.sum)
      expect(component.tooltip_values.sum).to eq(5_000)
    end
  end
end
