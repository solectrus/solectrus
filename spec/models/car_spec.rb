# == Schema Information
#
# Table name: cars
#
#  id           :integer          not null, primary key
#  active_from  :date             not null
#  active_until :date
#  color        :string
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
describe Car do
  describe 'validations' do
    it 'accepts the numbers up to the limit' do
      expect(described_class.new(id: Sensor::Cars::MAX)).to be_valid
      expect(described_class.new(id: Sensor::Cars::MAX + 1)).not_to be_valid
    end

    it 'accepts a hex code as color' do
      expect(described_class.new(id: 1, color: '#3B82F6')).to be_valid
      expect(described_class.new(id: 1, color: 'blue')).not_to be_valid
    end

    it 'needs a first day, the installation date by default' do
      car = described_class.new(id: 1)

      expect(car.active_from).to eq(Rails.configuration.x.installation_date)
      expect(described_class.new(id: 1, active_from: nil)).not_to be_valid
    end

    it 'refuses a last day before the first day' do
      car = described_class.new(id: 1, active_from: Date.new(2026, 5, 1), active_until: Date.new(2026, 4, 30))

      expect(car).not_to be_valid
      expect(car.errors[:active_until]).to be_present
    end

    it 'refuses a period that leaves an offsite session outside' do
      car = described_class.create!(id: 1)
      ChargingSession.create!(kind: :offsite, car:, started_at: Time.zone.local(2026, 3, 1, 12), kwh: 10, cost: 5)

      expect(car.update(active_from: Date.new(2026, 4, 1))).to be(false)
      expect(car.errors[:base]).to be_present
    end

    # Shortly after local midnight is the previous day in UTC
    it 'accepts a period that starts on the day of an offsite session' do
      car = described_class.create!(id: 1)
      ChargingSession.create!(kind: :offsite, car:, started_at: Time.zone.local(2026, 4, 1, 0, 30), kwh: 10, cost: 5)

      expect(car.update(active_from: Date.new(2026, 4, 1))).to be(true)
    end

    it 'refuses a period without a first day' do
      car = described_class.create!(id: 1)
      ChargingSession.create!(kind: :offsite, car:, started_at: Time.zone.local(2026, 3, 1, 12), kwh: 10, cost: 5)

      expect(car.update(active_from: nil)).to be(false)
      expect(car.errors[:active_from]).to be_present
    end
  end

  describe '.names' do
    it 'reads the names of the cars with a name' do
      described_class.create!(id: 1, name: 'Model Y')
      described_class.create!(id: 2)

      expect(described_class.names).to eq(1 => 'Model Y')
    end

    it 'clears the names after a write' do
      car = described_class.create!(id: 1, name: 'Model Y')
      described_class.names

      car.update!(name: 'Model 3')

      expect(described_class.name_of(1)).to eq('Model 3')
    end

    it 'has the default name of I18n for a car without a name' do
      expect(described_class.display_name_of(2)).to eq('Car 2')
    end
  end

  describe '#display_color' do
    it 'has the default color of its number without a color of its own' do
      expect(described_class.new(id: 2).display_color).to eq(described_class.default_color(2))
      expect(described_class.new(id: 2, color: '#ff0000').display_color).to eq('#ff0000')
    end
  end

  describe 'a change of the period' do
    let(:car) { described_class.create!(id: 1) }
    let(:day) { Date.new(2026, 3, 15) }

    before do
      travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
      ((day - 1)..(day + 1)).each do |date|
        Summary.create!(date:, charging_sessions_version: ChargingSession::Detection::VERSION)
      end
      ChargingSession.create!(
        kind: :wallbox, car:, started_at: day.in_time_zone.change(hour: 12), ended_at: day.in_time_zone.change(hour: 13), kwh: 10,
      )
    end

    it 'takes the car from each wallbox session outside the period' do
      car.update!(active_until: day - 1)

      expect(ChargingSession.sole.car_id).to be_nil
    end

    # Shortly after local midnight is the previous day in UTC
    it 'keeps the car of a session on the first day of the period' do
      ChargingSession.sole.update!(started_at: day.in_time_zone.change(hour: 0, min: 30))
      car.update!(active_from: day)

      expect(ChargingSession.sole.car_id).to eq(car.id)
    end

    it 'marks the days between the old and the new bound for the detection' do
      car.update!(active_until: day)

      expect(Summary.where(charging_sessions_version: nil).pluck(:date)).to contain_exactly(day, day + 1)
    end
  end
end
