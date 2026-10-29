describe Car::Spans do
  subject(:spans) { described_class.for(Timeframe.new(timeframe), selected_cars) }

  let!(:cars) { [Car.create!(id: 1), Car.create!(id: 2)] }
  let(:selected_cars) { [cars.first] }
  let(:timeframe) { '2026-03' }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  before { travel_to Time.zone.local(2026, 5, 15, 12) }

  # [lowest value, highest value, their timeframes]
  def summary_of(span) = [span.min, span.max, span.min_timeframe.to_s, span.max_timeframe.to_s]

  describe 'the rates' do
    # The car drives 40 km every five days and charges once a month, more in
    # each month, so each month has a rate of its own
    before do
      driving_days = [1, 6, 11, 16, 21, 26]
      (1..4).each do |month|
        driving_days.each { summary(Date.new(2026, month, it), 'car_odometer_1', 'sum', 40) }
        start = Time.zone.local(2026, month, 3, 12)
        ChargingSession.create!(kind: :wallbox, origin: :detection, car_id: 1, started_at: start, ended_at: start + 1.hour, kwh: (month * 10) + 20, cost: month + 5.0)
      end
    end

    # The same of the values of the months, like the driving card shows them
    def monthly
      values =
        (1..5).filter_map do |month|
          timeframe = Timeframe.new("2026-#{month.to_s.rjust(2, '0')}")
          (value = yield Car::Report.new(timeframe, selected_cars)) && [value, timeframe.to_s]
        end
      min, max = values.minmax_by(&:first)
      [min.first, max.first, min.last, max.last]
    end

    it 'spans the consumption of the months' do
      expect(summary_of(spans.consumption_per_100km)).to eq(monthly { it.driving.consumption_per_100km })
    end

    it 'spans the cost per 100 km of the months' do
      expect(summary_of(spans.cost_per_100km)).to eq(monthly { it.driving.cost_per_100km })
    end

    context 'with a year' do
      let(:timeframe) { '2026' }

      it 'has no span, because one year says nothing' do
        expect(spans.consumption_per_100km).to be_nil
      end
    end
  end

  describe '#max_range' do
    before do
      summary(Date.new(2026, 1, 10), 'car_max_range_1', 'avg', 300)
      summary(Date.new(2026, 2, 10), 'car_max_range_1', 'avg', 340)
      summary(Date.new(2026, 3, 10), 'car_max_range_1', 'avg', 320)
    end

    it 'spans the average of the months, with the month of each end' do
      expect(summary_of(spans.max_range)).to eq([300, 340, '2026-01', '2026-02'])
    end

    context 'with a car that started in the middle of a month' do
      let!(:cars) { [Car.create!(id: 1, active_from: Date.new(2026, 1, 5))] }

      before do
        summary(Date.new(2026, 4, 10), 'car_max_range_1', 'avg', 330)
      end

      it 'leaves out this month, because the car was not in use on each of its days' do
        expect(summary_of(spans.max_range)).to eq([320, 340, '2026-03', '2026-02'])
      end

      context 'when this month is shown' do
        let(:timeframe) { '2026-01' }

        it 'counts it, so its value lies in the span' do
          expect(summary_of(spans.max_range)).to eq([300, 340, '2026-01', '2026-02'])
        end
      end
    end

    context 'with a car that ended in the middle of a month' do
      let!(:cars) { [Car.create!(id: 1, active_until: Date.new(2026, 3, 15))] }
      let(:timeframe) { '2026-02' }

      before do
        summary(Date.new(2025, 12, 10), 'car_max_range_1', 'avg', 310)
        summary(Date.new(2026, 3, 12), 'car_max_range_1', 'avg', 350)
      end

      it 'leaves out this month' do
        expect(summary_of(spans.max_range)).to eq([300, 340, '2026-01', '2026-02'])
      end
    end

    context 'with a week' do
      let(:timeframe) { '2026-W11' }

      it 'names the weeks of the ends' do
        expect(summary_of(spans.max_range)).to eq([300, 340, '2026-W02', '2026-W07'])
      end
    end

    context 'with a day' do
      let(:timeframe) { '2026-03-10' }

      it 'names the days of the ends' do
        expect(summary_of(spans.max_range)).to eq([300, 340, '2026-01-10', '2026-02-10'])
      end
    end

    context 'with the selection "all" of several cars' do
      let(:selected_cars) { cars }

      it 'has none, because the cars have batteries of their own' do
        expect(spans.max_range).to be_nil
      end
    end
  end

  context 'with the same value in each period' do
    before { (1..3).each { summary(Date.new(2026, it, 10), 'car_max_range_1', 'avg', 300) } }

    it 'has no span' do
      expect(spans.max_range).to be_nil
    end
  end

  describe 'the cache' do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      (1..3).each { summary(Date.new(2026, it, 10), 'car_max_range_1', 'avg', it + 300) }
      described_class.for(Timeframe.new(timeframe), selected_cars).max_range
      allow(Car::Report).to receive(:new).and_call_original
    end

    it 'holds the spans' do
      expect(spans.max_range.max).to eq(303)
      expect(Car::Report).not_to have_received(:new)
    end

    context 'with a car that started in the middle of a month' do
      let!(:cars) { [Car.create!(id: 1, active_from: Date.new(2026, 1, 5))] }

      # March has two months that count, too few for a span
      it 'shares the entry with the other months, and still counts the shown one' do
        span = described_class.for(Timeframe.new('2026-01'), selected_cars).max_range

        expect(spans.max_range).to be_nil
        expect(summary_of(span)).to eq([301, 303, '2026-01', '2026-03'])
        expect(Car::Report).not_to have_received(:new)
      end
    end

    it 'computes them again after a change of a summary' do
      summary(Date.new(2026, 4, 10), 'car_max_range_1', 'avg', 310)

      expect(spans.max_range.max).to eq(310)
    end

    # The older session leaves the time of the last update as it is
    it 'computes them again after a deleted charging session' do
      older, = [3, 4].map do |day|
        start = Time.zone.local(2026, 4, day, 12)
        ChargingSession.create!(kind: :wallbox, origin: :detection, car_id: 1, started_at: start, ended_at: start + 1.hour, kwh: 10, updated_at: start)
      end
      described_class.for(Timeframe.new(timeframe), selected_cars).max_range
      older.delete

      spans.max_range

      expect(Car::Report).to have_received(:new).twice
    end
  end

  context 'with the whole time' do
    let(:timeframe) { 'all' }

    it 'has no periods of its kind' do
      expect(spans).to be_nil
    end
  end
end
