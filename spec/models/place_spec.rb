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
