# == Schema Information
#
# Table name: cars
#
#  id           :integer          not null, primary key
#  active_from  :date             not null
#  active_until :date
#  color        :string
#  name         :string
#  short_name   :string           not null
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

    it 'limits the short name' do
      expect(described_class.new(id: 1, short_name: 'a' * Car::SHORT_NAME_MAX)).to be_valid
      expect(described_class.new(id: 1, short_name: 'a' * (Car::SHORT_NAME_MAX + 1))).not_to be_valid
      expect(described_class.new(id: 1, short_name: ' ').short_name).to be_nil
    end

    it 'takes the number as short name of a new car, and then needs one' do
      car = described_class.create!(id: 2)

      expect(car.short_name).to eq('2')
      expect(car.update(short_name: '')).to be(false)
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
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 3, 1, 12), kwh: 10, cost: 5)

      expect(car.update(active_from: Date.new(2026, 4, 1))).to be(false)
      expect(car.errors[:base]).to be_present
    end

    # Shortly after local midnight is the previous day in UTC
    it 'accepts a period that starts on the day of an offsite session' do
      car = described_class.create!(id: 1)
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 4, 1, 0, 30), kwh: 10, cost: 5)

      expect(car.update(active_from: Date.new(2026, 4, 1))).to be(true)
    end

    it 'refuses a period without a first day' do
      car = described_class.create!(id: 1)
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 3, 1, 12), kwh: 10, cost: 5)

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

    it 'gives a guest the default names, also as short name' do
      car = described_class.create!(id: 1, name: 'Model Y', short_name: 'MY')
      Current.car_names_hidden = true

      expect(car.display_name).to eq('Car 1')
      expect(car.short_name).to eq('Car 1')
    end
  end

  describe '#active_during?' do
    let(:car) { described_class.new(id: 1, active_from: Date.new(2026, 3, 10), active_until: Date.new(2026, 5, 20)) }

    it 'holds dates that touch the period' do
      expect(car.active_during?(Date.new(2026, 3, 1)..Date.new(2026, 3, 10))).to be(true)
      expect(car.active_during?(Date.new(2026, 5, 20)..Date.new(2026, 5, 31))).to be(true)
      expect(car.active_during?(Date.new(2026, 1, 1)..Date.new(2026, 12, 31))).to be(true)
    end

    it 'does not hold dates outside the period' do
      expect(car.active_during?(Date.new(2026, 3, 1)..Date.new(2026, 3, 9))).to be(false)
      expect(car.active_during?(Date.new(2026, 5, 21)..Date.new(2026, 5, 31))).to be(false)
    end
  end

  describe '#display_color' do
    it 'has the default color without a color of its own' do
      expect(described_class.new(id: 2).display_color).to eq(described_class::DEFAULT_COLOR)
      expect(described_class.new(id: 2, color: '#ff0000').display_color).to eq('#ff0000')
    end
  end

  describe 'a change of the period' do
    let(:car) { described_class.create!(id: 1) }
    let(:day) { Date.new(2026, 3, 15) }

    before do
      travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
      ((day - 1)..(day + 1)).each do |date|
        Summary.create!(date:, steps: Summary::Steps.versions)
      end
      ChargingSession.create!(
        kind: :wallbox, origin: :detection, car:, started_at: day.in_time_zone.change(hour: 12), ended_at: day.in_time_zone.change(hour: 13), kwh: 10,
      )
    end

    it 'takes the car from each wallbox session outside the period' do
      car.update!(active_until: day - 1)

      expect(ChargingSession.sole.car_id).to be_nil
    end

    it 'gives the detection a session outside the period that the user assigned' do
      ChargingSession.sole.update_columns(assigned_manually: true) # rubocop:disable Rails/SkipsModelValidations

      car.update!(active_until: day - 1)

      expect(ChargingSession.sole).to have_attributes(car_id: nil, assigned_manually: false)
    end

    # Shortly after local midnight is the previous day in UTC
    it 'keeps the car of a session on the first day of the period' do
      ChargingSession.sole.update!(started_at: day.in_time_zone.change(hour: 0, min: 30))
      car.update!(active_from: day)

      expect(ChargingSession.sole.car_id).to eq(car.id)
    end

    it 'marks the days between the old and the new bound for the detection' do
      car.update!(active_until: day)

      expect(Summary.without_step(:charging_sessions).pluck(:date)).to contain_exactly(day, day + 1)
    end

    it 'removes the daily values of the car outside the period' do
      ((day - 1)..(day + 1)).each do |date|
        SummaryValue.create!(date:, field: 'car_odometer_1', aggregation: 'sum', value: 30)
        SummaryValue.create!(date:, field: 'car_odometer_2', aggregation: 'sum', value: 20)
      end

      car.update!(active_until: day)

      expect(SummaryValue.where(field: 'car_odometer_1').pluck(:date)).to contain_exactly(day - 1, day)
      expect(SummaryValue.where(field: 'car_odometer_2').count).to eq(3)
    end

    it 'builds the days again that the period gains' do
      car.update!(active_from: day)
      car.update!(active_from: day - 1)

      expect(Summary.pluck(:date)).to contain_exactly(day, day + 1)
    end
  end

  describe '.configured' do
    before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_3' => 'car3:odometer')) }

    after { Sensor::Config.setup(ENV) }

    # The test configuration has the state of charge of the first car
    it 'creates a car for each configured number without a car' do
      expect(described_class.configured.map(&:id)).to eq([1, 3])
    end

    it 'takes the number as short name of a new car' do
      expect(described_class.configured.map(&:short_name)).to eq(%w[1 3])
    end

    it 'starts a new car at the installation date' do
      expect(described_class.configured.map(&:active_from).uniq).to eq([Rails.configuration.x.installation_date])
    end

    it 'keeps an existing car' do
      described_class.create!(id: 3, name: 'Wartburg')

      expect { described_class.configured }.to change(described_class, :count).from(1).to(2)
      expect(described_class.find(3).name).to eq('Wartburg')
    end

    it 'gives no car to a number without a configuration' do
      described_class.create!(id: 2)

      expect(described_class.configured.map(&:id)).to eq([1, 3])
    end
  end
end
