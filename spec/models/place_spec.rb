# == Schema Information
#
# Table name: places
#
#  id          :bigint           not null, primary key
#  geocoded_at :datetime
#  geocoding   :jsonb
#  labels      :string           default([]), not null, is an Array
#  latitude    :float            not null
#  longitude   :float            not null
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_places_on_home  ((1)) UNIQUE WHERE ('home'::text = ANY ((labels)::text[]))
#
describe Place do
  let(:home) { described_class.create!(latitude: 50.92263, longitude: 6.40706) }

  def stop(latitude, longitude, duration)
    Place::VisitDetection::Stop.new(latitude:, longitude:, from: Time.current, to: Time.current + duration, longest: duration, limit: described_class::MIN_DURATION)
  end

  describe '.near' do
    before { home }

    it 'finds a place within the radius' do
      # About 9 m away
      expect(described_class.near(50.92270, 6.40710)).to eq(home)
    end

    it 'finds no place farther away' do
      # About 1.8 km away
      expect(described_class.near(50.90600, 6.40700)).to be_nil
    end
  end

  describe '.around' do
    before { home }

    it 'selects a place within the radius, also to the east' do
      # About 90 m east, which is more than RADIUS in degrees of latitude
      expect(described_class.around(50.92263, 6.40835)).to contain_exactly(home)
    end

    it 'selects no place farther away' do
      # About 150 m east
      expect(described_class.around(50.92263, 6.40920)).to be_empty
    end
  end

  describe '.of' do
    before { home }

    it 'gives each stop its place, and a long stop a new one' do
      places = described_class.of([stop(50.92270, 6.40710, 60), stop(50.90600, 6.40700, 1.hour), stop(50.80000, 6.40000, 10.minutes)])

      expect(places.first).to eq(home)
      expect(places.second).to have_attributes(latitude: 50.906, longitude: 6.407)
      expect(places.third).to be_nil
    end
  end

  describe '.with_seconds' do
    it 'adds up the visits of each place, the most time first' do
      car = Car.configured.first
      work = described_class.create!(latitude: 50.906, longitude: 6.407)
      empty = described_class.create!(latitude: 50.8, longitude: 6.4)
      start = Date.yesterday.beginning_of_day
      home.visits.create!(car:, date: start.to_date, started_at: start, ended_at: start + 600)
      work.visits.create!(car:, date: start.to_date, started_at: start + 1.hour, ended_at: start + 2.hours)
      home.visits.create!(car:, date: Date.current, started_at: start + 1.day, ended_at: start + 1.day + 900)

      expect(described_class.with_seconds.map { [it, it.seconds] }).to eq([[work, 3600], [home, 1500], [empty, 0]])
    end
  end

  describe '#labels' do
    it 'keeps the known labels, in their order' do
      home.update!(labels: ['', 'unknown', 'home', 'home'])

      expect(home.reload.labels).to eq(['home'])
    end

    it 'moves home from the old place to the new one' do
      work = described_class.create!(latitude: 50.906, longitude: 6.407)
      home.update!(labels: ['home'])
      work.update!(labels: ['home'])

      expect(described_class.home).to eq(work)
      expect(home.reload).not_to be_home
    end
  end

  describe '#display_name' do
    it 'prefers the name of the user to the town' do
      home.update!(name: '  Home ', geocoding: { 'address' => { 'town' => 'Jülich' } })

      expect(home.display_name).to eq('Home')
    end

    it 'falls back to the town' do
      home.update!(name: ' ', geocoding: { 'address' => { 'town' => 'Jülich' } })

      expect(home.display_name).to eq('Jülich')
    end

    it 'falls back to the district and the town' do
      home.update!(geocoding: { 'address' => { 'city' => 'Köln', 'city_district' => 'Lindenthal', 'suburb' => 'Braunsfeld' } })

      expect(home.display_name).to eq('Braunsfeld, Köln')
    end
  end

  describe '#locality' do
    def locality(address) = described_class.new(geocoding: { 'address' => address }).locality

    it 'takes the village of a small town as its district' do
      expect(locality('town' => 'Jülich', 'village' => 'Lich-Steinstraß', 'hamlet' => 'Lorsbeck')).to eq('Lich-Steinstraß, Jülich')
    end

    it 'gives a district that names the town alone' do
      expect(locality('city' => 'Bonn', 'city_district' => 'Stadtbezirk Bonn', 'quarter' => 'Bonn-Zentrum')).to eq('Bonn-Zentrum')
    end

    it 'gives a village without a town alone' do
      expect(locality('village' => 'Köttenich', 'hamlet' => 'Köttenicher Mahlmühle')).to eq('Köttenich')
    end

    it 'is nil before an answer of Nominatim' do
      expect(described_class.new.locality).to be_nil
    end
  end

  describe 'the address' do
    before do
      home.update!(geocoding: { 'address' => { 'road' => 'Main Street', 'house_number' => '15', 'postcode' => '12345', 'village' => 'Hamlet', 'town' => 'Jülich' } })
    end

    it 'takes the town before the village' do
      expect(home.town).to eq('Jülich')
    end

    it 'gives the street and the town' do
      expect(home.address).to eq('Main Street 15, 12345 Jülich')
    end
  end

  describe '#geocode!' do
    let(:answer) { { 'address' => { 'town' => 'Jülich' } } }

    before { allow(Place::Nominatim).to receive(:reverse).and_return(answer) }

    it 'asks Nominatim once and keeps the answer' do
      2.times { home.geocode! }

      expect(home.reload).to have_attributes(geocoding: answer, town: 'Jülich')
      expect(Place::Nominatim).to have_received(:reverse).once
    end

    it 'waits after a failure' do
      allow(Place::Nominatim).to receive(:reverse).and_return(nil)
      2.times { home.geocode! }

      expect(Place::Nominatim).to have_received(:reverse).once
    end

    it 'asks nothing without Nominatim' do
      allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)
      home.geocode!

      expect(home.reload.geocoded_at).to be_nil
      expect(Place::Nominatim).not_to have_received(:reverse)
    end
  end

  describe 'the name at a location' do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(Place::Nominatim).to receive(:reverse).and_return({ 'address' => { 'town' => 'Jülich' } })
    end

    it 'knows no name before an answer of Nominatim' do
      expect(described_class.known_name_at(50.92263, 6.40706)).to be_nil
      expect(Place::Nominatim).not_to have_received(:reverse)
    end

    it 'gives the name of the nearest place' do
      home.update!(name: 'Home')

      expect(described_class.known_name_at(50.92265, 6.4071)).to eq('Home')
    end

    it 'keeps the town of a place in the place' do
      home

      expect(described_class.name_at(50.92265, 6.4071)).to eq('Jülich')
      expect(home.reload.town).to eq('Jülich')
    end

    it 'keeps the town of a location without a place in the cache, and makes no place' do
      2.times { described_class.name_at(50.92263, 6.40706) }

      expect(described_class.known_name_at(50.92263, 6.40706)).to eq('Jülich')
      expect(described_class.count).to eq(0)
      expect(Place::Nominatim).to have_received(:reverse).once
    end

    it 'asks once for locations close together' do
      described_class.name_at(50.92263, 6.40706)

      expect(described_class.known_name_at(50.92401, 6.40998)).to eq('Jülich')
      expect(Place::Nominatim).to have_received(:reverse).once
    end

    it 'keeps no failure in the cache' do
      allow(Place::Nominatim).to receive(:reverse).and_return(nil)
      2.times { described_class.name_at(50.92263, 6.40706) }

      expect(Place::Nominatim).to have_received(:reverse).twice
    end
  end
end
