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
          ChargingSession::Sums.new(count: 2, kwh: 13.0, kwh_grid: 2.0, cost: 1.4, cost_grid: 0.6, uncosted: 1, unsplit: 1),
        [car.id, false, day, 'offsite'] =>
          ChargingSession::Sums.new(count: 1, kwh: 5.0, kwh_grid: 0.0, cost: 3.0, cost_grid: 0.0, uncosted: 0, unsplit: 0),
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
end
