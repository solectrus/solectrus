describe Car::DrivingCostTooltip::Component, type: :component do
  subject(:text) { render_inline(described_class.new(balance:)).text.squish }

  let(:balance) do
    instance_double(
      Car::Balance,
      driving: Car::DailyRates::Totals.new(distance: 4200, energy_wh: 840_000, cost_distance: 4200, cost: 252.0),
      car_cost_per_100km: 6.0,
      car_driving_costs: 252.0,
      car_distance:,
    )
  end
  let(:car_distance) { 4200 }

  # The user can multiply the two factors and get the driving cost
  it 'gives the distance, the rate and the driving cost' do
    expect(text).to include('4,200 km', '6.00 €', 'Driving cost', '252 €')
  end

  it 'has no note when all days have a rate' do
    expect(text).not_to include('days without a rate')
  end

  context 'with days without a rate' do
    let(:car_distance) { 4210 }

    # The distance of the card is larger than the distance of the calculation
    it 'names their kilometers' do
      expect(text).to include('Without 10 km that lack charging data')
    end
  end

  it 'leaves the charging cost out' do
    expect(text).not_to include('Charging cost')
  end

  context 'without a rate' do
    let(:balance) do
      instance_double(
        Car::Balance,
        driving: Car::DailyRates::Totals.new(distance: 0, energy_wh: 0, cost_distance: 0, cost: 0),
        car_cost_per_100km: nil,
        car_driving_costs: nil,
      )
    end

    it 'says why the driving cost is missing' do
      expect(text).to include('100 km at least')
    end
  end
end
