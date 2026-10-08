describe Car::Report do
  subject(:report) { described_class.new(timeframe, selected_cars) }

  let!(:cars) { [Car.create!(id: 1), Car.create!(id: 2)] }
  let(:selected_cars) { cars }
  let(:timeframe) { Timeframe.new('2026-01') }

  def wallbox(day, kwh:, **attributes)
    start = Time.zone.local(2026, 1, day, 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh:, **attributes)
  end

  def summary(day, field, aggregation, value)
    date = Date.new(2026, 1, day)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)

    # Both odometers read from the start of the month
    summary(1, 'car_odometer_1', 'sum', 0)
    summary(1, 'car_odometer_2', 'sum', 0)
    summary(10, 'car_odometer_1', 'sum', 120)
    summary(10, 'car_max_range_1', 'avg', 380)
    summary(25, 'car_odometer_2', 'sum', 100)
    summary(11, 'car_max_range_1', 'avg', 420)

    wallbox(10, kwh: 10, kwh_grid: 4, cost: 1.6, cost_grid: 1.2, car_id: 1)
    wallbox(11, kwh: 20, kwh_grid: 0, cost: 2.0, cost_grid: 0, car_id: 2)
    wallbox(12, kwh: 5, guest: true, cost: 1.5)
    wallbox(13, kwh: 7)
    ChargingSession.create!(kind: :offsite, origin: :user, car_id: 1, started_at: Time.zone.local(2026, 1, 14, 12), kwh: 8, cost: 4.0)
  end

  describe '.pending_days' do
    it 'asks for the days of the timeframe plus the margin, with the detection' do
      allow(Summary).to receive(:missing_or_stale_days).and_return([])

      described_class.pending_days(timeframe)

      expect(Summary).to have_received(:missing_or_stale_days).with(
        from: Date.new(2025, 12, 18), to: Date.new(2026, 2, 14), steps: Car::Report::STEPS,
      )
    end
  end

  describe '#distance' do
    it 'adds the distance of the selected cars' do
      expect(report.distance).to eq(220)
    end

    context 'with one car selected' do
      let(:selected_cars) { [cars.second] }

      it { expect(report.distance).to eq(100) }
    end

    context 'without a value' do
      let(:timeframe) { Timeframe.new('2026-02') }

      it { expect(report.distance).to be_nil }
    end
  end

  describe '#km_per_day' do
    # The queries that read the first value of each odometer
    def first_value_queries(&)
      queries = []
      collect = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('MIN("summary_values"."date")') }
      ActiveSupport::Notifications.subscribed(collect, 'sql.active_record', &)
      queries
    end

    it 'divides the distance by the days of the period' do
      expect(report.km_per_day).to eq(220.fdiv(31))
    end

    context 'with a day' do
      let(:timeframe) { Timeframe.new('2026-01-10') }

      it 'has no average and reads no first value of an odometer' do
        expect(first_value_queries { expect(report.km_per_day).to be_nil }).to be_empty
      end
    end

    context 'without a distance' do
      let(:timeframe) { Timeframe.new('2026-02') }

      it 'has no average and reads no first value of an odometer' do
        expect(first_value_queries { expect(report.km_per_day).to be_nil }).to be_empty
      end
    end

    context 'with a car that starts in the period' do
      let(:selected_cars) { [cars.second] }

      # A new build gives the days that the period gains a value
      before do
        cars.second.update!(active_from: Date.new(2026, 1, 22))
        summary(22, 'car_odometer_2', 'sum', 0)
      end

      it 'counts only the days in use' do
        expect(report.km_per_day).to eq(10)
      end
    end

    # One car until the 14th, the other one from the 22nd: 24 days in use
    context 'with "all" and a gap between the periods' do
      before do
        cars.first.update!(active_until: Date.new(2026, 1, 14))
        cars.second.update!(active_from: Date.new(2026, 1, 22))
        summary(22, 'car_odometer_2', 'sum', 0)
      end

      it 'counts the days on which a car was in use' do
        expect(report.km_per_day).to eq(220.fdiv(24))
      end
    end

    # The odometer came on the 10th, so the days before it have no distance
    context 'with an odometer that starts in the period' do
      let(:selected_cars) { [cars.first] }

      before { SummaryValue.where(date: Date.new(2026, 1, 1), field: 'car_odometer_1').delete_all }

      it 'counts the days from its first value' do
        expect(report.km_per_day).to eq(120.fdiv(22))
      end
    end
  end

  describe '#max_range' do
    it 'has none for "all"' do
      expect(report.max_range).to be_nil
    end

    context 'with one car selected' do
      let(:selected_cars) { [cars.first] }

      it 'is the average of the days' do
        expect(report.max_range).to eq(400)
      end
    end
  end

  describe '#driving_cost' do
    # 18 kWh for 5.60 EUR over 120 km, and 20 kWh for 2 EUR over 100 km
    it 'is the driving cost of the days of the period' do
      expect(report.driving_cost).to be_within(0.001).of(7.6)
    end

    context 'with a session without a cost' do
      before { wallbox(15, kwh: 3, car_id: 1) }

      it 'has none for the car of the session' do
        expect(report.driving_cost).to be_within(0.001).of(2.0)
      end
    end
  end

  describe '#maximum' do
    it 'finds the day with the highest distance' do
      expect(report.maximum(:car_distance)).to eq([Date.new(2026, 1, 10), 120])
    end

    # 20 kWh of car 2, without the guest session and the unassigned one
    it 'finds the day with the most charged energy in Wh' do
      expect(report.maximum(:car_charging)).to eq([Date.new(2026, 1, 11), 20_000])
    end

    it 'finds the day with the highest driving cost' do
      date, cost = report.maximum(:car_driving_costs)

      expect(date).to eq(Date.new(2026, 1, 10))
      expect(cost).to be_within(0.001).of(5.6)
    end

    it 'has none for a rate' do
      expect(report.maximum(:car_cost_rate)).to be_nil
    end
  end

  describe 'a number that a page reads more than once' do
    # Each spy calls the original
    def spy_on(klass, *methods)
      instances = []
      allow(klass).to receive(:new).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap do |instance|
          methods.each { allow(instance).to receive(it).and_call_original }
          instances << instance
        end
      end
      instances
    end

    it 'passes over the days once' do
      ledgers = spy_on(Car::Ledger, :sessions, :distance)

      2.times do
        report.sessions(:wallbox)
        report.km_per_day
      end

      expect(ledgers.sole).to have_received(:sessions).once
      expect(ledgers.sole).to have_received(:distance).once
    end

    it 'drives the days of each car once, for each car and for "all"' do
      drivings = spy_on(Car::Driving, :totals)

      cars.each { report.driving(cars: [it]) }
      report.driving

      expect(drivings.sole).to have_received(:totals).twice
    end
  end

  describe 'the charging of "all"' do
    it 'is the sum of the sessions of the cars, without the guest and the open sessions' do
      expect(report.sessions.kwh).to eq(38)
      expect(report.sessions.cost).to be_within(0.001).of(7.6)
    end

    it 'counts the sessions of each kind' do
      expect(report.sessions(:wallbox)).to have_attributes(count: 2, kwh: 30)
      expect(report.sessions(:offsite)).to have_attributes(count: 1, kwh: 8, cost: 4.0)
    end

    it 'names the guest sessions and the sessions that are not assigned' do
      expect(report.guest_sessions).to have_attributes(count: 1, kwh: 5, cost: 1.5)
      expect(report.unassigned_sessions).to have_attributes(count: 1, kwh: 7)
    end

    it 'splits the wallbox into PV and grid with the power splitter' do
      stub_feature(:power_splitter)

      expect(report).to be_split
      expect(report.sessions(:wallbox)).to have_attributes(kwh_pv: 26, kwh_grid: 4)
    end

    it 'knows that a session has no cost' do
      wallbox(15, kwh: 3, car_id: 1)

      expect(report.sessions).not_to be_costed
    end
  end

  describe 'a session before the period' do
    before do
      ChargingSession.create!(kind: :offsite, origin: :user, car_id: 1, started_at: Time.zone.local(2025, 12, 25, 12), kwh: 50, cost: 9.0)
    end

    it 'does not count for the charging of the period' do
      expect(report.sessions.kwh).to eq(38)
    end
  end

  describe 'the charging of one car' do
    let(:selected_cars) { [cars.first] }

    it 'is the sum of the sessions of the car' do
      expect(report.sessions.kwh).to eq(18)
      expect(report.sessions.cost).to be_within(0.001).of(5.6)
    end
  end
end
