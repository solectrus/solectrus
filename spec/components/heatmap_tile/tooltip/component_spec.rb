describe HeatmapTile::Tooltip::Component, type: :component do
  def amounts_shown(value)
    render_inline(
      described_class.new(
        value:,
        sensor: Sensor::Registry[:grid_power],
        date: Date.new(2026, 9, 1),
      ),
    )

    page.all('.sensor-value').map { it.text.to_f }
  end

  # In whole euros, this could only add up as 4 - 1 = 3
  it 'keeps the cents of small amounts' do
    expect(
      amounts_shown(grid_revenue: 3.47, grid_costs: 0.89, grid_balance: 2.58),
    ).to eq([3.47, 0.89, 2.58])
  end

  # Rounded on their own, the rows show 1,23 - 0,46 = 0,78. The costs keep
  # their value, as in the other tooltips, and the revenue takes the rest.
  it 'rounds the grid amounts to add up to the balance' do
    expect(
      amounts_shown(grid_revenue: 1.234, grid_costs: 0.456, grid_balance: 0.778),
    ).to eq([1.24, 0.46, 0.78])
  end
end
