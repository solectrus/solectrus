describe ConsumeDetails::Component, type: :component do
  subject(:component) { described_class.new(data:) }

  let(:data) do
    Sensor::Data::Single.new(
      {
        grid_costs: 4.834,
        opportunity_costs: 10.204,
        total_costs: 15.038,
        grid_import_power: 16_000,
        self_consumption: 48_000,
      },
      timeframe: Timeframe.day,
    )
  end

  # The key figure shows 4,83 EUR for the grid costs. Rounded on their own, the
  # rows would show 4,83 + 10 = 15.
  it 'keeps the grid costs of the key figure and adds up to the total' do
    expect(component.costs.parts).to eq([4.83, 10.21])
    expect(component.costs.sum).to eq(15.04)
  end

  it 'shows all amounts with the precision of the grid costs' do
    render_inline(component)

    expect(page).to have_text('10.21')
    expect(page).to have_text('15.04')
  end
end
