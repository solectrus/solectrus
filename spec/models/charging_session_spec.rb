# == Schema Information
#
# Table name: charging_sessions
#
#  id         :bigint           not null, primary key
#  address    :string
#  cost       :decimal(10, 2)
#  cost_grid  :decimal(10, 2)
#  ended_at   :datetime
#  guest      :boolean          default(FALSE), not null
#  kind       :string           not null
#  kwh        :decimal(10, 3)   not null
#  kwh_grid   :decimal(10, 3)
#  note       :text
#  power_type :string
#  provider   :string
#  started_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  car_id     :integer
#  evse_id    :string
#
# Indexes
#
#  index_charging_sessions_on_car_id_and_started_at  (car_id,started_at)
#  index_charging_sessions_on_kind_and_started_at    (kind,started_at)
#  index_charging_sessions_on_wallbox_start          (started_at) UNIQUE WHERE ((kind)::text = 'wallbox'::text)
#
# Foreign Keys
#
#  charging_sessions_car_id_fkey  (car_id => cars.id)
#
describe ChargingSession do
  let(:car) { Car.create!(id: 1) }

  describe 'validations' do
    context 'when offsite' do
      subject(:session) { described_class.offsite.new(car:, started_at: Time.current, kwh: 10, cost: 5) }

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

  describe '#state' do
    it 'names the three states of a wallbox session' do
      expect(described_class.new(car:).state).to eq(:car)
      expect(described_class.new(guest: true).state).to eq(:guest)
      expect(described_class.new.state).to eq(:not_assigned)
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
    let!(:recent_offsite) { described_class.create!(kind: :offsite, car:, started_at: 2.days.ago, kwh: 10, cost: 5) }
    let!(:old_offsite) { described_class.create!(kind: :offsite, car:, started_at: 2.years.ago, kwh: 20, cost: 10) }
    let!(:guest) do
      described_class.create!(kind: :wallbox, guest: true, started_at: 1.day.ago, ended_at: 1.day.ago + 1.hour, kwh: 7)
    end
    let!(:open_task) do
      described_class.create!(kind: :wallbox, started_at: 3.days.ago, ended_at: 3.days.ago + 1.hour, kwh: 5)
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
      expect(described_class.list_for(:wallbox, filter: :not_assigned)).to eq([open_task])
    end
  end

  describe '.totals' do
    before do
      described_class.create!(kind: :offsite, car:, started_at: 1.day.ago, kwh: 10, cost: 5.5)
      described_class.create!(
        kind: :wallbox, car:, started_at: 2.days.ago, ended_at: 2.days.ago + 1.hour, kwh: 15, kwh_grid: 5, cost: 2.5,
      )
      described_class.create!(kind: :wallbox, car:, started_at: 3.days.ago, ended_at: 3.days.ago + 1.hour, kwh: 7)
    end

    it 'sums the energy, the grid energy and the cost, and counts the sessions without a cost or a split' do
      expect(described_class.totals).to eq(
        kwh: 32.0, kwh_grid: 22.0, cost: 8.0, count: 3, without_cost: 1, without_split: 1,
      )
    end
  end
end
