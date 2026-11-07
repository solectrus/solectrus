describe Car::Savings do
  subject(:amounts) { described_class.new(report).amounts }

  let!(:car) { Car.create!(id: 1, fuel_type: 'petrol', fuel_consumption: 6) }
  let(:dates) { Date.new(2026, 3, 1)..Date.new(2026, 3, 31) }
  let(:comparison) { instance_double(Car::Comparison, ready?: true) }
  let(:report) { report_of(dates) }

  def report_of(dates)
    timeframe = instance_double(Timeframe, effective_dates: dates, min_date: nil)
    instance_double(Car::Report, timeframe:, dates:, cars: [car], guest?: false, comparison:)
  end

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    travel_to Time.zone.local(2026, 5, 15, 12)
    allow(Sensor::Query::FuelPrices).to receive(:new).and_return(instance_double(Sensor::Query::FuelPrices, call: [[Date.new(2026, 1, 5), 1.80]]))
    allow(Car::ComparisonAmounts).to receive(:new).with(comparison).and_return(
      instance_double(Car::ComparisonAmounts, precision: 0, car_cost: 412, combustion_cost: 980),
    )
  end

  it 'gives the amounts of the page' do
    expect(amounts).to have_attributes(precision: 0, car_cost: 412.0, combustion_cost: 980.0, savings: 568.0)
  end

  it 'reads the amounts from the cache the next time' do
    2.times { described_class.new(report).amounts }

    expect(Car::ComparisonAmounts).to have_received(:new).once
  end

  context 'without a compared distance' do
    let(:comparison) { instance_double(Car::Comparison, ready?: false) }

    it { is_expected.to be_nil }
  end

  describe 'a change of an input' do
    before { described_class.new(report).amounts }

    def summary(date) = Summary.create!(date:)

    it 'calculates again with a new charging session' do
      start = Time.zone.local(2026, 3, 3, 12)
      ChargingSession.create!(kind: :wallbox, origin: :detection, car_id: 1, started_at: start, ended_at: start + 1.hour, kwh: 20, cost: 5.0)

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    it 'calculates again with a new payment' do
      Car::Payment.create!(car:, category: :insurance, date: Date.new(2026, 3, 1), amount: 300)

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    it 'calculates again with another consumption of the combustion car' do
      car.update!(fuel_consumption: 7)

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    it 'calculates again with a new price' do
      Price.create!(name: :electricity, starts_at: Date.new(2026, 1, 1), value: 0.30)

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    # The rate of a day comes from the days around it
    it 'calculates again with a new summary near the dates' do
      summary(Date.new(2026, 4, 10))

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    # The factors of the month and the year come from the whole year
    it 'calculates again with a new summary in the year of the dates' do
      summary(Date.new(2026, 1, 5))

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).twice
    end

    it 'keeps the amounts with a summary far from the dates' do
      summary(Date.new(2025, 6, 1))

      amounts
      expect(Car::ComparisonAmounts).to have_received(:new).once
    end
  end
end
