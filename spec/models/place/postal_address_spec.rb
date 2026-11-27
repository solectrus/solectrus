describe Place::PostalAddress do
  let(:address) { described_class.new(country_code: 'DE', postcode: '12345', town: 'Town', street: 'Main Street', house_number: '15') }

  describe '#to_s' do
    it 'puts the country, the postcode and the town first' do
      expect(address.to_s).to eq('DE-12345 Town, Main Street 15')
    end

    it 'leaves out a missing part' do
      expect(address.with(street: nil).to_s).to eq('DE-12345 Town, 15')
    end
  end

  describe '#domestic' do
    it 'puts the street first, without the country' do
      expect(address.domestic).to eq('Main Street 15, 12345 Town')
    end

    it 'leaves out a missing part' do
      expect(described_class.new(country_code: nil, postcode: nil, town: nil, street: 'Main Street', house_number: nil).domestic).to eq('Main Street')
    end
  end
end
