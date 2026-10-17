describe ChargingSession::AddressLookup do
  subject(:lookup) { described_class.new(session) }

  let(:car) { Car.create!(id: 1) }
  let(:session) do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 1.day.ago, kwh: 10, cost: 5).tap do
      it.update_columns(latitude: 50.0, longitude: 8.0) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  let(:found) do
    Place.new(
      latitude: 51.0,
      longitude: 7.0,
      geocoding: { 'address' => { 'country_code' => 'de', 'postcode' => '12345', 'town' => 'Town', 'road' => 'Main Street', 'house_number' => '1' } },
    )
  end

  before { allow(Place).to receive(:search).and_return(found) }

  describe '#save' do
    it 'gives a new address its position and its normal form' do
      session.address = 'main street 1, 12345 Town'

      expect(lookup.save).to be(true)
      expect(session.reload).to have_attributes(address: 'DE-12345 Town, Main Street 1', location: [51.0, 7.0])
      expect(Place).to have_received(:search).with('main street 1, 12345 Town')
    end

    it 'asks Nominatim before the save opens its transaction' do
      outside = ChargingSession.connection.open_transactions
      inside = nil
      allow(Place).to receive(:search) do
        inside = ChargingSession.connection.open_transactions
        found
      end
      session.address = 'main street 1, 12345 Town'

      expect(lookup.save).to be(true)

      expect(inside).to eq(outside)
    end

    it 'refuses an address that Nominatim does not find, and keeps the position' do
      allow(Place).to receive(:search).and_return(nil)
      session.address = 'Nowhere'

      expect(lookup.save).to be(false)
      expect(session.errors[:address]).to include('was not found')
      expect(session.reload.location).to eq([50.0, 8.0])
    end

    it 'refuses a new address that Nominatim cannot check' do
      allow(Place).to receive(:search).and_raise(Place::Nominatim::Unavailable)
      session.address = 'DE-12345 Town, Main Street 1'

      expect(lookup.save).to be(false)
      expect(session.errors[:address]).to include('cannot be checked right now. Try again later.')
    end

    it 'keeps an address without Nominatim as it is, with the position of the car' do
      allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)
      session.address = 'main street 1, Town'

      expect(lookup.save).to be(true)
      expect(session.reload).to have_attributes(address: 'main street 1, Town', location: [50.0, 8.0])
      expect(Place).not_to have_received(:search)
    end

    it 'removes the position with the address' do
      session.update_columns(address: 'DE-12345 Town, Main Street 1') # rubocop:disable Rails/SkipsModelValidations
      session.address = ''

      expect(lookup.save).to be(true)

      expect(session.reload.location).to be_nil
    end

    it 'keeps the position that the form carries for the address' do
      session.assign_attributes(address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Main Street 1')

      expect(lookup.save).to be(true)

      expect(session.reload.location).to eq([50.0, 8.0])
      expect(Place).not_to have_received(:search)
    end

    it 'gives an entered session its position' do
      offsite = ChargingSession.new(kind: :offsite, origin: :user, car:, started_at: 1.day.ago, kwh: 10, cost: 5, address: 'Main Street 1, Town')

      expect(described_class.new(offsite).save).to be(true)

      expect(offsite.reload).to have_attributes(address: 'DE-12345 Town, Main Street 1', location: [51.0, 7.0])
    end
  end

  describe '#check' do
    it 'gives the position and the normal form without a save' do
      offsite = ChargingSession.new(kind: :offsite, address: 'Main Street 1, 12345 Town')
      described_class.new(offsite).check

      expect(offsite).to have_attributes(address: 'DE-12345 Town, Main Street 1', location: [51.0, 7.0], persisted?: false)
    end

    it 'marks an address that Nominatim does not find, and clears the position' do
      allow(Place).to receive(:search).and_return(nil)
      offsite = ChargingSession.new(kind: :offsite, address: 'Nowhere', latitude: 50.0, longitude: 8.0)
      described_class.new(offsite).check

      expect(offsite.errors[:address]).to be_present
      expect(offsite.location).to be_nil
    end
  end

  describe '#prepare' do
    it 'carries the position for the address, and asks nothing' do
      session.update_columns(address: 'DE-12345 Town, Main Street 1') # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:address_at)
      lookup.prepare

      expect(session.address_of_position).to eq('DE-12345 Town, Main Street 1')
      expect(lookup).not_to be_pending
      expect(Place).not_to have_received(:search)
      expect(Place).not_to have_received(:address_at)
    end

    it 'leaves an address from before without a position to the form' do
      session.update_columns(latitude: nil, longitude: nil, address: 'Main Street 1, 12345 Town') # rubocop:disable Rails/SkipsModelValidations
      lookup.prepare

      expect(lookup).to be_pending
      expect(Place).not_to have_received(:search)
    end

    it 'leaves the address at a position without an address to the form' do
      allow(Place).to receive(:address_at)
      lookup.prepare

      expect(lookup).to be_pending
      expect(Place).not_to have_received(:address_at)
    end

    it 'leaves nothing to the form without Nominatim' do
      allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)
      lookup.prepare

      expect(lookup).not_to be_pending
    end
  end

  describe '#complete' do
    context 'with an address from before without a position' do
      before { session.update_columns(latitude: nil, longitude: nil, address: 'Main Street 1, 12345 Town') } # rubocop:disable Rails/SkipsModelValidations

      it 'gives the address its position and its normal form, and saves nothing' do
        lookup.complete

        expect(session).to have_attributes(address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Main Street 1', location: [51.0, 7.0])
        expect(session.reload).to have_attributes(address: 'Main Street 1, 12345 Town', location: nil)
      end

      it 'marks an address that Nominatim does not find' do
        allow(Place).to receive(:search).and_return(nil)
        lookup.complete

        expect(session.errors[:address]).to be_present
        expect(session.reload.address).to eq('Main Street 1, 12345 Town')
      end
    end

    it 'offers the address at a position without an address, and carries the position for it' do
      allow(Place).to receive(:address_at).with(50.0, 8.0).and_return('DE-12345 Town, Main Street 1')
      session.address = ''
      lookup.complete

      expect(session).to have_attributes(address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Main Street 1')
      expect(session.reload.address).to be_nil
    end
  end
end
