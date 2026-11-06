describe McpServer::Tools::CarCosts::Comparison do
  let(:report) { instance_double(Car::Report) }

  describe '.note' do
    it 'says why without fuel prices for the fuel of each car' do
      comparison = instance_double(Car::Comparison, possible?: false)

      expect(described_class.note(report, comparison)).to eq(
        'No comparison with a combustion car: there are no fuel prices for the fuel of each car yet.',
      )
    end

    it 'says why without a distance in the timeframe' do
      comparison = instance_double(Car::Comparison, possible?: true, ready?: false)

      expect(described_class.note(report, comparison)).to eq(
        'No comparison with a combustion car: no distance to compare in this timeframe.',
      )
    end

    it 'has nothing to say about a comparison that is ready' do
      comparison = instance_double(Car::Comparison, possible?: true, ready?: true)

      expect(described_class.note(report, comparison)).to be_nil
    end
  end

  describe '.gap' do
    def gap(key, value = nil) = described_class.gap(Car::ComparisonGaps::Gap.new(key, value))

    it 'counts the proposals that wait for a confirmation' do
      expect(gap(:proposals, 3)).to eq(
        '3 offsite charging sessions wait for a confirmation, so their cost is missing.',
      )
    end

    it 'names the kilometers without a cost or a fuel price' do
      expect(gap(:unrated, 42)).to eq(
        '42 km have no cost or no fuel price and are left out on all sides.',
      )
    end

    it 'explains the missing power splitter' do
      expect(gap(:splitter)).to include('Without a power splitter')
    end

    it 'names the cars without a vehicle tax' do
      cars = [Car.new(id: 1), Car.new(id: 2)]

      expect(gap(:tax, cars)).to eq('No vehicle tax of the combustion car for car 1, car 2.')
    end
  end
end
