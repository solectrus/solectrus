describe Sensor::Chart::CarRateBase do
  let(:today) { Date.new(2026, 9, 23) }

  before do
    travel_to today.in_time_zone.change(hour: 12)

    # 30 kWh from the grid for 9 EUR and 150 km late in January
    start = Date.new(2026, 1, 25).in_time_zone.change(hour: 12)
    ChargingSession.create!(
      kind: :wallbox,
      car: Car.create!(id: 1),
      started_at: start,
      ended_at: start + 1.hour,
      kwh: 30,
      kwh_grid: 30,
      cost: 9,
    )
    summary(Date.new(2026, 1, 25), :car_mileage_1, :sum, 150)
  end

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  def rates(chart)
    chart.data[:datasets].first[:data]
  end

  describe Sensor::Chart::CarConsumptionRate do
    subject(:chart) { described_class.new(timeframe:) }

    context 'with a year' do
      let(:timeframe) { Timeframe.new('2026') }

      it 'has a column for each month until today' do
        expect(chart.data[:labels].size).to eq(9)
      end

      # Only January drives, so only January has a rate
      it 'gives each month the rate of its days' do
        expect(rates(chart).first(3)).to eq([20.0, nil, nil])
      end

      it 'is labelled in kWh/100 km' do
        expect(chart.unit).to eq('kWh/100 km')
      end

      it 'shows one decimal' do
        expect(chart.decimals).to eq(1)
      end

      # September ends today
      it 'hatches the column of the current month' do
        expect(chart.data[:datasets].first[:hatchFill]).to eq(([false] * 8) + [true])
      end
    end

    context 'with all years' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2024, 3, 1)) }

      it 'hatches the years before the installation date and after today' do
        expect(chart.data[:datasets].first[:hatchFill]).to eq([true, false, true])
      end
    end

    context 'with a month' do
      let(:timeframe) { Timeframe.new('2026-01') }

      it 'has a column for each day' do
        expect(chart.data[:labels].size).to eq(31)
      end

      it 'hatches no day' do
        expect(chart.data[:datasets].first[:hatchFill]).to all(be(false))
      end
    end

    context 'when a window has less than 100 km' do
      let(:timeframe) { Timeframe.new('2026') }

      before do
        SummaryValue.find_by!(date: Date.new(2026, 1, 25), field: :car_mileage_1)
          .update!(value: 99)
      end

      it 'leaves a gap' do
        expect(rates(chart).first).to be_nil
      end
    end

    context 'with a day' do
      let(:timeframe) { Timeframe.new('2026-01-15') }

      it 'has no data, because a rate of an hour means nothing' do
        expect(chart.data).to be_nil
      end
    end
  end

  describe Sensor::Chart::CarCostRate do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026')) }

    # 30 kWh * 0.30 EUR = 9 EUR for 150 km
    it 'gives the cost of the window for each 100 km' do
      expect(rates(chart).first).to be_within(0.001).of(6.0)
    end

    it 'shows the cents' do
      expect(chart.decimals).to eq(2)
    end

    it 'says that each day has a window of its own' do
      notes = chart.data[:datasets].first[:tooltipNotes]

      expect(notes.first).to eq(['Each day at the rate of the 14 days before and after it'])
      expect(notes.third).to be_nil
    end
  end

  describe Sensor::Chart::CarDrivingCosts do
    subject(:chart) { described_class.new(timeframe:) }

    context 'with a year' do
      let(:timeframe) { Timeframe.new('2026') }

      # 150 km at 9 EUR / 150 km in January, and no distance after it
      it 'gives each month the driving cost of its days' do
        expect(rates(chart).first(3)).to eq([9.0, nil, nil])
      end

      it 'explains each column with the calculation and the daily rate' do
        notes = chart.data[:datasets].first[:tooltipNotes]
        rate_unit = Sensor::UnitFormatter.format(unit: :money_per_100km, context: :total)

        expect(notes.first).to eq(
          ["150 km × 6.00 #{rate_unit}", 'Each day at the rate of the 14 days before and after it'],
        )
        expect(notes.third).to be_nil
      end
    end

    context 'with years as columns' do
      let(:timeframe) { Timeframe.new('all') }

      before do
        start = Date.new(2025, 6, 15).in_time_zone.change(hour: 12)
        ChargingSession.create!(
          kind: :wallbox,
          car_id: 1,
          started_at: start,
          ended_at: start + 1.hour,
          kwh: 30,
          kwh_grid: 30,
          cost: 9,
        )
        summary(Date.new(2025, 6, 15), :car_mileage_1, :sum, 150)
      end

      # 9 EUR in 2025 and 9 EUR in 2026
      it 'gives columns that add up to the driving cost of all days' do
        expect(rates(chart).compact.sum).to be_within(0.001).of(18.0)
      end
    end

    context 'with a day' do
      let(:timeframe) { Timeframe.new('2026-01-15') }

      it 'has no data, because a column needs the distance of a whole day' do
        expect(chart).not_to be_supported
        expect(chart.data).to be_nil
      end
    end
  end
end
