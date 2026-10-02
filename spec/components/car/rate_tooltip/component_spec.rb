describe Car::RateTooltip::Component, type: :component do
  subject(:text) do
    render_inline(described_class.new(driving:, rate:)).text.squish
  end

  let(:driving) do
    Car::DailyRates::Totals.new(distance: 3048, energy_wh: 689_100, cost_distance: 3048, cost: 167.72)
  end

  context 'with the cost rate' do
    let(:rate) { :cost }

    # The user can divide the driving cost by the distance and get the rate
    it 'gives the driving cost, the distance and the rate' do
      expect(text).to include('Driving costs', '167.72 €', '3,048 km', '5.50 €')
    end

    it 'says that each day has a window of its own' do
      expect(text).to include('Each day therefore takes the rate of the 14 days before and after it')
    end
  end

  context 'with the consumption rate' do
    let(:rate) { :consumption }

    it 'gives the energy, the distance and the rate' do
      expect(text).to include('Energy for driving', '689 kWh', '3,048 km', '22.6 kWh')
    end

    it 'says that the values include the charging losses' do
      expect(text).to include('charging losses')
    end
  end

  context 'with the distance of the card' do
    subject(:text) do
      render_inline(described_class.new(driving:, rate: :cost, distance: 3058)).text.squish
    end

    it 'names the kilometers of the days without a rate' do
      expect(text).to include('Without 10 km that lack charging data')
    end
  end

  context 'with an unknown rate' do
    let(:rate) { :range }

    it { expect { text }.to raise_error(ArgumentError) }
  end
end
