# == Schema Information
#
# Table name: charging_sessions
#
#  id                :bigint           not null, primary key
#  address           :string
#  assigned_manually :boolean          default(FALSE), not null
#  cost              :decimal(10, 2)
#  cost_grid         :decimal(10, 2)
#  ended_at          :datetime
#  guest             :boolean          default(FALSE), not null
#  kind              :string           not null
#  kwh               :decimal(10, 3)   not null
#  kwh_grid          :decimal(10, 3)
#  note              :text
#  origin            :string           not null
#  power_type        :string
#  provider          :string
#  started_at        :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  car_id            :integer
#  evse_id           :string
#
# Indexes
#
#  index_charging_sessions_on_car_id_and_started_at  (car_id,started_at)
#  index_charging_sessions_on_kind_and_started_at    (kind,started_at)
#  index_charging_sessions_on_wallbox_start          (started_at) UNIQUE WHERE (((kind)::text = 'wallbox'::text) AND ((origin)::text = 'detection'::text))
#
# Foreign Keys
#
#  charging_sessions_car_id_fkey  (car_id => cars.id)
#
describe ChargingSession do
  let(:car) { Car.create!(id: 1) }

  describe 'validations' do
    context 'when offsite' do
      subject(:session) { described_class.offsite.new(origin: :user, car:, started_at: Time.current, kwh: 10, cost: 5) }

      it { is_expected.to validate_presence_of(:cost) }
      it { is_expected.to validate_presence_of(:car) }
      it { is_expected.to validate_numericality_of(:kwh).is_greater_than(0) }

      it 'requires non-negative cost' do
        expect(session).to validate_numericality_of(:cost).is_greater_than_or_equal_to(0)
      end

      it 'is no guest charge' do
        session.guest = true

        expect(session).not_to be_valid
        expect(session.errors[:guest]).to be_present
      end

      describe 'the period of the car' do
        let(:last_day) { 3.days.ago.to_date }

        before { car.update!(active_until: last_day) }

        it 'takes a session in the period' do
          session.assign_attributes(started_at: last_day.in_time_zone.change(hour: 20), ended_at: last_day.in_time_zone.change(hour: 22))

          expect(session).to be_valid
        end

        it 'refuses a session that ends after the period' do
          session.assign_attributes(started_at: last_day.in_time_zone.change(hour: 22), ended_at: (last_day + 1).in_time_zone.change(hour: 2))

          expect(session).not_to be_valid
          expect(session.errors[:car_id]).to be_present
        end

        it 'checks a change of the end alone' do
          session.update!(started_at: last_day.in_time_zone.change(hour: 20), ended_at: last_day.in_time_zone.change(hour: 22))

          expect(session.update(ended_at: (last_day + 1).in_time_zone.change(hour: 2))).to be(false)
        end
      end
    end

    context 'when wallbox' do
      subject(:session) do
        described_class.wallbox.new(started_at: 1.hour.ago, ended_at: Time.current, kwh: 10)
      end

      it { is_expected.to validate_presence_of(:ended_at) }

      it 'is valid without cost and without a car' do
        expect(session).to be_valid
      end

      it 'is a guest charge only without a car' do
        session.assign_attributes(guest: true, car:)

        expect(session).not_to be_valid
        expect(session.errors[:guest]).to be_present
      end

      it 'refuses a car outside its period' do
        car.update!(active_until: 2.days.ago.to_date)
        session.car = car

        expect(session).not_to be_valid
        expect(session.errors[:car_id]).to be_present
      end
    end
  end

  describe 'assigned_manually' do
    let(:started_at) { 1.day.ago }

    def wallbox(**) = described_class.create!(kind: :wallbox, origin: :detection, started_at:, ended_at: started_at + 1.hour, kwh: 5, **)

    it 'is false for a session of the detection' do
      expect(wallbox(car:)).not_to be_assigned_manually
    end

    it 'is true for an offsite session and a guest charge' do
      expect(described_class.create!(kind: :offsite, origin: :user, car:, started_at:, kwh: 5, cost: 2)).to be_assigned_manually
      expect(wallbox(guest: true)).to be_assigned_manually
    end

    it 'becomes true when the car changes' do
      session = wallbox

      session.update!(car:)

      expect(session).to be_assigned_manually
    end

    it 'stays false when only the note changes' do
      session = wallbox(car:)

      session.update!(note: 'Trip')

      expect(session).not_to be_assigned_manually
    end
  end

  describe 'origin' do
    let(:started_at) { 1.day.ago }

    it 'has no default' do
      expect { described_class.create!(kind: :offsite, car:, started_at:, kwh: 5, cost: 2) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'refuses the user for a wallbox session' do
      expect { described_class.create!(kind: :wallbox, origin: :user, started_at:, ended_at: started_at + 1.hour, kwh: 5) }
        .to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe '#state' do
    it 'names the three states of a wallbox session' do
      expect(described_class.new(car:).state).to eq(:car)
      expect(described_class.new(guest: true).state).to eq(:guest)
      expect(described_class.new.state).to eq(:unassigned)
    end
  end

  describe '#holder' do
    it 'reads and writes the three states as one value' do
      session = described_class.new(car:)
      expect(session.holder).to eq('1')

      session.holder = described_class::GUEST
      expect(session).to have_attributes(guest: true, car_id: nil, holder: described_class::GUEST)

      session.holder = ''
      expect(session).to have_attributes(guest: false, car_id: nil, holder: '')

      session.holder = '1'
      expect(session).to have_attributes(guest: false, car_id: 1)
    end
  end

  describe '#destroy' do
    it 'keeps a wallbox session, which the detection writes again' do
      session = described_class.create!(kind: :wallbox, origin: :detection, started_at: 1.day.ago, ended_at: 1.day.ago + 1.hour, kwh: 7)

      expect(session.destroy).to be(false)
      expect(described_class.exists?(session.id)).to be(true)
    end

    it 'removes an offsite session' do
      session = described_class.create!(kind: :offsite, origin: :user, car:, started_at: 1.day.ago, kwh: 7, cost: 3)

      expect(session.destroy).to be_truthy
      expect(described_class.exists?(session.id)).to be(false)
    end
  end

  describe '#kwh_pv' do
    it 'is the rest of a wallbox session with a grid share' do
      expect(described_class.wallbox.new(kwh: 10, kwh_grid: 4).kwh_pv).to eq(6)
    end

    it 'is nil for a wallbox session without a grid share' do
      expect(described_class.wallbox.new(kwh: 10).kwh_pv).to be_nil
    end

    it 'is zero for an offsite session' do
      expect(described_class.offsite.new(kwh: 10).kwh_pv).to eq(0)
    end
  end

  describe '#pv_percent' do
    it 'rounds the PV share to whole percent' do
      expect(described_class.wallbox.new(kwh: 3, kwh_grid: 1).pv_percent).to eq(67)
    end

    it 'has none without a grid share' do
      expect(described_class.wallbox.new(kwh: 3).pv_percent).to be_nil
    end
  end

  describe '.list_for' do
    let!(:recent_offsite) { described_class.create!(kind: :offsite, origin: :user, car:, started_at: 2.days.ago, kwh: 10, cost: 5) }
    let!(:old_offsite) { described_class.create!(kind: :offsite, origin: :user, car:, started_at: 2.years.ago, kwh: 20, cost: 10) }
    let!(:guest) do
      described_class.create!(kind: :wallbox, origin: :detection, guest: true, started_at: 1.day.ago, ended_at: 1.day.ago + 1.hour, kwh: 7)
    end
    let!(:open_task) do
      described_class.create!(kind: :wallbox, origin: :detection, started_at: 3.days.ago, ended_at: 3.days.ago + 1.hour, kwh: 5)
    end

    it 'scopes by kind and orders by started_at desc when timeframe is nil' do
      expect(described_class.list_for(:offsite)).to eq([recent_offsite, old_offsite])
    end

    it 'returns all matching sessions for timeframe all' do
      expect(described_class.list_for(:offsite, timeframe: Timeframe.new('all'))).to eq([recent_offsite, old_offsite])
    end

    it 'filters by timeframe range when not all' do
      expect(described_class.list_for(:offsite, timeframe: Timeframe.new(Date.current.strftime('%Y'))))
        .to eq([recent_offsite])
    end

    it 'filters by car, guest and not assigned' do
      expect(described_class.list_for(:offsite, filter: 1)).to eq([recent_offsite, old_offsite])
      expect(described_class.list_for(:wallbox, filter: :guest)).to eq([guest])
      expect(described_class.list_for(:wallbox, filter: :unassigned)).to eq([open_task])
    end
  end

  describe '.sums' do
    before do
      described_class.create!(kind: :offsite, origin: :user, car:, started_at: 1.day.ago, kwh: 10, cost: 5.5)
      described_class.create!(
        kind: :wallbox, origin: :detection, car:, started_at: 2.days.ago, ended_at: 2.days.ago + 1.hour, kwh: 15, kwh_grid: 5, cost: 2.5,
      )
      described_class.create!(kind: :wallbox, origin: :detection, car:, started_at: 3.days.ago, ended_at: 3.days.ago + 1.hour, kwh: 7)
    end

    it 'sums the energy and the cost, and counts the sessions without a cost or a split' do
      expect(described_class.sums).to have_attributes(kwh: 32.0, kwh_grid: 5.0, cost: 8.0, count: 3, rows: 3, uncosted: 1, unsplit: 1)
    end

    it 'gives the PV share of the wallbox sessions with a split' do
      sums = described_class.wallbox.where.not(kwh_grid: nil).sums

      expect(sums).to have_attributes(kwh_pv: 10.0, pv_percent: 67)
      expect(described_class.wallbox.sums.kwh_pv).to be_nil
    end
  end

  describe '.daily_sums' do
    def wallbox(start, kwh:, kwh_grid: nil, cost: nil, cost_grid: nil)
      described_class.create!(kind: :wallbox, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:, cost_grid:)
    end

    before do
      wallbox(Time.zone.local(2026, 1, 15, 12), kwh: 10, kwh_grid: 2, cost: 1.4, cost_grid: 0.6)
      wallbox(Time.zone.local(2026, 1, 15, 18), kwh: 3)
      described_class.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 1, 15, 20), kwh: 5, cost: 3)
    end

    it 'sums the sessions of each car, guest mark, day and kind' do
      day = Date.new(2026, 1, 15)

      expect(described_class.daily_sums).to eq(
        [car.id, false, day, 'wallbox'] =>
          ChargingSession::Sums.new(count: 2, rows: 2, kwh: 13.0, kwh_grid: 2.0, cost: 1.4, cost_grid: 0.6, uncosted: 1, unsplit: 1),
        [car.id, false, day, 'offsite'] =>
          ChargingSession::Sums.new(count: 1, rows: 1, kwh: 5.0, kwh_grid: 0.0, cost: 3.0, cost_grid: 0.0, uncosted: 0, unsplit: 0),
      )
    end

    # In UTC, this start is on the day before its local date
    it 'groups by the local date of the start, like #date' do
      session = wallbox(Time.zone.local(2026, 1, 16, 0, 30), kwh: 1)

      expect(session.started_at.utc.to_date).to eq(Date.new(2026, 1, 15))
      expect(described_class.wallbox.daily_sums.transform_keys { it[2] }.transform_values(&:kwh)).to eq(
        Date.new(2026, 1, 15) => 13.0,
        session.date => 1.0,
      )
    end
  end

  describe 'a charge over midnight' do
    let(:midnight) { Time.zone.local(2026, 1, 16) }

    # The detection cuts the charge at midnight (see Detection::Periods)
    let!(:evening) do
      described_class.create!(
        kind: :wallbox,
        car:,
        started_at: midnight - 2.hours,
        ended_at: midnight - 1.second,
        kwh: 10,
        kwh_grid: 2,
        cost: 2,
        origin: :detection,
        note: 'Trip',
      )
    end
    let!(:morning) do
      described_class.create!(kind: :wallbox, origin: :detection, car:, started_at: midnight, ended_at: midnight + 3.hours, kwh: 15, kwh_grid: 3, cost: 3)
    end

    it 'is one charge in the list' do
      charge = described_class.list_for(:wallbox).sole

      expect(charge).to have_attributes(
        id: evening.id,
        part_ids: [evening.id, morning.id],
        started_at: evening.started_at,
        ended_at: morning.ended_at,
        kwh: 25,
        kwh_grid: 5,
        cost: 5,
        note: 'Trip',
        car_id: car.id,
      )
    end

    it 'has no cost when a part has none' do
      morning.update!(cost: nil)

      expect(described_class.list_for(:wallbox).sole.cost).to be_nil
    end

    it 'counts once, and keeps the energy on each day' do
      expect(described_class.sums).to have_attributes(count: 1, rows: 2, kwh: 25.0)
      expect(described_class.daily_sums.transform_keys { it[2] }.transform_values { [it.count, it.kwh] }).to eq(
        Date.new(2026, 1, 15) => [1, 10.0],
        Date.new(2026, 1, 16) => [0, 15.0],
      )
    end

    it 'shows the part of a timeframe without the part before it' do
      charges = described_class.list_for(:wallbox, timeframe: Timeframe.new('2026-01-16'))

      expect(charges.map(&:part_ids)).to eq([[morning.id]])
      expect(described_class.on_dates(Date.new(2026, 1, 16)..Date.new(2026, 1, 16)).sums).to have_attributes(count: 1, rows: 1)
    end

    it 'joins no sessions of two holders' do
      morning.update!(car_id: nil, guest: true)

      expect(described_class.list_for(:wallbox).map(&:part_ids)).to eq([[morning.id], [evening.id]])
    end

    it 'joins no sessions with a gap that ends a period' do
      morning.update!(started_at: midnight + 20.minutes)

      expect(described_class.sums).to have_attributes(count: 2, rows: 2)
    end

    it 'joins a gap over midnight that does not end a period' do
      evening.update!(ended_at: midnight - 10.minutes)
      morning.update!(started_at: midnight + 4.minutes)

      expect(described_class.sums).to have_attributes(count: 1, rows: 2)
    end

    it 'joins no sessions of one day' do
      evening.update!(ended_at: midnight - 1.hour)
      morning.update!(started_at: midnight - 50.minutes, ended_at: midnight - 30.minutes)

      expect(described_class.sums).to have_attributes(count: 2, rows: 2)
    end

    describe '#update_parts' do
      it 'changes each part, and keeps the note at the head' do
        charge = morning.charge

        expect(charge.update_parts(car_id: nil, guest: true, note: 'Visitor')).to be(true)
        expect(evening.reload).to have_attributes(guest: true, car_id: nil, assigned_manually: true, note: 'Visitor')
        expect(morning.reload).to have_attributes(guest: true, car_id: nil, assigned_manually: true, note: nil)
      end

      it 'changes no part when one part is invalid' do
        other = Car.create!(id: 2, active_until: Date.new(2026, 1, 15))
        charge = evening.charge

        expect(charge.update_parts(car_id: other.id)).to be(false)
        expect(charge.errors[:car_id]).to be_present
        expect([evening.reload.car_id, morning.reload.car_id]).to eq([car.id, car.id])
      end
    end
  end
end
