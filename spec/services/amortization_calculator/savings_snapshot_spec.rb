describe AmortizationCalculator::SavingsSnapshot do
  subject(:snapshot) do
    described_class.new(measured:, installation_date: Date.new(2026, 1, 1), today:)
  end

  let(:measured) do
    AmortizationCalculator::MeasuredSavings.new(
      Date.new(2026, 1, 1) => 60.0,
      Date.new(2026, 2, 1) => 60.0,
    )
  end

  context 'with less than a year of data' do
    # 2026-01-01 up to 2026-03-01: 60 measured days
    let(:today) { Date.new(2026, 3, 1) }

    it 'projects from the average of all measured days' do
      aggregate_failures do
        expect(snapshot.projection_uncertain?).to be true
        expect(snapshot.daily_projection_rate).to eq(2.0)
        expect(snapshot.savings_per_year).to eq(730.0)
      end
    end
  end

  context 'with a full year of data' do
    let(:today) { Date.new(2027, 1, 15) }

    it 'projects from the rolling year' do
      aggregate_failures do
        expect(snapshot.projection_uncertain?).to be false
        expect(snapshot.daily_projection_rate).to eq(60.0 / 365)
      end
    end
  end
end
