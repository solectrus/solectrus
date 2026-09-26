describe SavingsDetails::Component, type: :component do
  subject(:component) { described_class.new(data:) }

  let(:data) do
    Sensor::Data::Single.new(
      {
        grid_costs: 12.344,
        grid_revenue: 3.456,
        solar_price: 8.888,
        traditional_costs: 30.004,
        savings: 21.116,
      },
      timeframe: Timeframe.day,
    )
  end

  # Rounded on their own, the rows show 12,34 - 3,46 = 8,89 and
  # 30,00 - 8,89 = 21,12, but they add up to 8,88 and 21,11
  it 'adds up both sums and keeps the savings of the key figure' do
    savings = component.savings
    solar_price = component.solar_price

    expect(savings.sum).to eq(21.12)
    expect(savings.parts.first).to eq(-solar_price.sum)
    expect((savings.parts.last - solar_price.sum).round(2)).to eq(savings.sum)
    expect(solar_price.parts.sum.round(2)).to eq(solar_price.sum)
  end
end
