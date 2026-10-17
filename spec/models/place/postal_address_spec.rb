describe Place::PostalAddress do
  describe '.parse' do
    def parse(text) = described_class.parse(text).to_h

    it 'takes the form of a charging point' do
      expect(parse('DE-65520 Bad Camberg, Neumarkt 3 a')).to eq(country_code: 'DE', postcode: '65520', town: 'Bad Camberg', street: 'Neumarkt', house_number: '3 a')
    end

    it 'takes the street first' do
      expect(parse('Main Street 15, 12345 Town')).to include(postcode: '12345', town: 'Town', street: 'Main Street', house_number: '15')
    end

    it 'takes a street and a postcode without a comma' do
      expect(parse('Karl-Heinz-Beckurts-Straße 13 52428 Jülich')).to include(postcode: '52428', town: 'Jülich', street: 'Karl-Heinz-Beckurts-Straße', house_number: '13')
    end

    it 'takes a postcode of the Netherlands' do
      expect(parse('NL-3253 LK Ouddorp, Noordweg 2')).to include(country_code: 'NL', postcode: '3253 LK', town: 'Ouddorp')
    end

    it 'takes a range of house numbers' do
      expect(parse('DE-99428 Hayn, Bergstraße 34 - 35')).to include(street: 'Bergstraße', house_number: '34 - 35')
    end

    it 'takes a country code in lowercase' do
      expect(parse('de-12345 Town, Main Street 15')).to eq(country_code: 'DE', postcode: '12345', town: 'Town', street: 'Main Street', house_number: '15')
    end

    it 'takes a word in mixed case as no country code' do
      expect(parse('St-Martin 5')).to include(country_code: nil, street: 'St-Martin', house_number: '5')
    end

    it 'keeps a dash in front without a country code' do
      expect(parse('-Main Street 1')).to include(country_code: nil, street: '-Main Street')
    end

    it 'takes no town that ends with a house number' do
      expect(parse('12345 Town Main Street 15')).to eq(country_code: nil, postcode: '12345', town: nil, street: 'Town Main Street', house_number: '15')
    end

    it 'leaves out what is not clear' do
      expect(parse('heisinger str 13, essen')).to eq(country_code: nil, postcode: nil, town: nil, street: 'heisinger str', house_number: '13')
    end
  end

  describe '#completed_by' do
    def found_by(address) = Place.new(geocoding: { 'address' => address }).postal_parts

    let(:found) do
      found_by(
        'country_code' => 'de',
        'postcode' => '97999',
        'village' => 'Harthausen',
        'municipality' => 'VVG der Stadt Bad Mergentheim',
        'road' => 'Reckerstal',
        'house_number' => '14 a',
      )
    end

    it 'takes the town and the house number of the user, the rest of Nominatim' do
      typed = described_class.parse('igersheim reckerstal 14, 97999 Igersheim')

      expect(typed.completed_by(found).to_s).to eq('DE-97999 Igersheim, Reckerstal 14')
    end

    it 'takes what the user left out from Nominatim' do
      expect(described_class.parse('Reckerstal').completed_by(found).to_s).to eq('DE-97999 Harthausen, Reckerstal 14 a')
    end

    it 'takes the town and the street of Nominatim after a town without a comma' do
      typed = described_class.parse('97999 Igersheim Reckerstal 14')

      expect(typed.completed_by(found).to_s).to eq('DE-97999 Harthausen, Reckerstal 14')
    end

    it 'keeps the street of the user when Nominatim has none' do
      typed = described_class.parse('AT-6105 Leutasch, Burggraben 264')
      found = found_by('country_code' => 'at', 'postcode' => '6105', 'village' => 'Leutasch', 'house_number' => '264')

      expect(typed.completed_by(found).to_s).to eq('AT-6105 Leutasch, Burggraben 264')
    end
  end

  describe '#domestic' do
    it 'puts the street first, without the country' do
      expect(described_class.parse('DE-12345 Town, Main Street 15').domestic).to eq('Main Street 15, 12345 Town')
    end

    it 'leaves out a missing part' do
      expect(described_class.parse('Main Street').domestic).to eq('Main Street')
    end
  end
end
