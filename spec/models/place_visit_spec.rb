# == Schema Information
#
# Table name: place_visits
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  ended_at   :datetime         not null
#  seconds    :integer
#  started_at :datetime         not null
#  car_id     :integer          not null
#  place_id   :bigint           not null
#
# Indexes
#
#  index_place_visits_on_car_id_and_started_at    (car_id,started_at) UNIQUE
#  index_place_visits_on_date                     (date)
#  index_place_visits_on_place_id_and_started_at  (place_id,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (car_id => cars.id)
#  fk_rails_...  (place_id => places.id) ON DELETE => cascade
#
describe PlaceVisit do
  let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706) }
  let(:work) { Place.create!(latitude: 50.906, longitude: 6.407) }
  let(:car) { Car.configured.first }

  def visit(place, from, to)
    started_at = Time.zone.parse(from)
    place.visits.create!(car:, date: started_at.to_date, started_at:, ended_at: Time.zone.parse(to))
  end

  before do
    visit(home, '2026-09-21 18:00', '2026-09-22 00:00')
    visit(home, '2026-09-22 00:00', '2026-09-22 07:20')
    visit(work, '2026-09-22 07:25', '2026-09-22 16:00')
    visit(home, '2026-09-22 16:00', '2026-09-23 00:00')
    visit(home, '2026-09-23 00:00', '2026-09-23 08:00')
  end

  describe '.counts' do
    # The visit over the night to the 22nd overlaps the day, and the visit
    # over the night to the 23rd starts on it
    it 'counts the joined visits that overlap the timeframe, and their places' do
      expect(described_class.counts(Timeframe.new('2026-09-22'))).to eq(visits: 3, places: 2)
    end

    it 'keeps the scope' do
      expect(described_class.where(place: work).counts(Timeframe.new('2026-09-23'))).to eq(visits: 0, places: 0)
    end
  end

  describe '.joined' do
    it 'joins the rows of a visit over midnight, the latest first' do
      visits = described_class.joined.map { [it.place_id, it.started_at.strftime('%d. %H:%M'), it.ended_at.strftime('%d. %H:%M'), it.seconds] }

      expect(visits).to eq(
        [
          [home.id, '22. 16:00', '23. 08:00', 16.hours],
          [work.id, '22. 07:25', '22. 16:00', 515.minutes],
          [home.id, '21. 18:00', '22. 07:20', 800.minutes],
        ],
      )
    end

    it 'keeps the scope' do
      expect(described_class.where(place: work).joined.map(&:place)).to eq([work])
    end
  end

  describe '.mark_ongoing' do
    # The latest visit of the car ends at the home on the 23rd
    def mark(latitude, longitude)
      state = Car::Live::State.new(car:, soc: nil, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude:, longitude:)
      allow(Car::Live).to receive(:new).and_return(instance_double(Car::Live, states: [state]))

      described_class.joined.to_a.tap { described_class.mark_ongoing(it) }
    end

    it 'marks the latest visit while the car is still at its place' do
      expect(mark(home.latitude, home.longitude).map(&:ongoing?)).to eq([true, false, false])
    end

    it 'marks no visit when the car is away' do
      expect(mark(work.latitude, work.longitude).map(&:ongoing?)).to eq([false, false, false])
    end

    it 'marks no visit without a position' do
      expect(mark(nil, nil).map(&:ongoing?)).to eq([false, false, false])
    end

    it 'asks for no position without the latest visit of a car' do
      allow(Car::Live).to receive(:new)
      described_class.mark_ongoing(described_class.where(place: work).joined.to_a)

      expect(Car::Live).not_to have_received(:new)
    end
  end

  describe '#current_seconds' do
    it 'is the time of an ended visit' do
      expect(described_class.joined.first.current_seconds).to eq(16.hours)
    end

    it 'lasts up to now while the visit is ongoing' do
      visit = described_class.joined.first
      visit.ongoing = true

      travel_to(Time.zone.parse('2026-09-23 10:00')) do
        expect(visit.current_seconds).to eq(18.hours)
      end
    end
  end
end
