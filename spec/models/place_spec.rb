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
end
