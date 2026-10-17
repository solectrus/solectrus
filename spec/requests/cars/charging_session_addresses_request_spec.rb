describe 'The address check of the form of a charging session' do
  before { login_as_admin }

  let(:found_place) do
    Place.new(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'country_code' => 'de', 'postcode' => '12345', 'town' => 'Town', 'road' => 'Main Street' } })
  end

  # The streams of the answer as HTML, which parsed_body leaves a string
  def html = Nokogiri::HTML4(response.body) # rubocop:disable Rails/ResponseParsedBody

  def check(id: nil, opened: nil, **params)
    post ['/cars/charging_sessions', id, 'address'].compact.join('/'), params: { opened:, charging_session: params }.compact, as: :turbo_stream
  end

  def field(name) = html.at_css("input[name=\"charging_session[#{name}]\"]")

  it 'gives the address in its normal form with its position and its map' do
    allow(Place).to receive(:search).with('main street 1, town').and_return(found_place)
    check(address: 'main street 1, town', address_of_position: 'DE-99999 Old Town, Old Street 1')

    body = html
    expect(body.at_css('input[name="charging_session[address]"]')['value']).to eq('DE-12345 Town, Main Street 1')
    expect(body.at_css('input[name="charging_session[address_of_position]"]')['value']).to eq('DE-12345 Town, Main Street 1')
    expect(body.at_css('input[name="charging_session[latitude]"]')['value']).to eq('51.0')
    expect(body.at_css('[data-controller="car--map--component"]')).to be_present
  end

  it 'lets the save keep the checked position, without a second request' do
    car = Car.create!(id: 1)
    session = ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 2.days.ago, kwh: 10, cost: 5)
    allow(Place).to receive(:search).and_return(found_place)
    check(address: 'main street 1, town')
    hidden = %w[address address_of_position latitude longitude].index_with { html.at_css("input[name=\"charging_session[#{it}]\"]")['value'] }

    patch "/cars/charging_sessions/#{session.id}", params: { charging_session: hidden }, as: :turbo_stream

    expect(session.reload).to have_attributes(address: 'DE-12345 Town, Main Street 1', latitude: 51.0, longitude: 7.0)
    expect(Place).to have_received(:search).once
  end

  it 'marks an address that Nominatim does not find in the place of the map, and clears the position' do
    allow(Place).to receive(:search).and_return(nil)
    check(address: 'Nowhere', latitude: '50.0', longitude: '8.0')

    body = html
    expect(body.at_css('#charging_session_map').text.squish).to eq('Address was not found')
    expect(body.at_css('#charging_session_address_field').text).not_to include('was not found')
    expect(field(:address)['aria-describedby']).to eq('charging_session_map_message')
    expect(body.at_css('input[name="charging_session[latitude]"]')['value']).to be_nil
    expect(body.at_css('[data-controller="car--map--component"]')).to be_nil
  end

  it 'asks nothing for the address that the form carries the position for' do
    allow(Place).to receive(:search)
    check(address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Main Street 1', latitude: '50.0', longitude: '8.0')

    expect(Place).not_to have_received(:search)
    expect(html.at_css('[data-controller="car--map--component"]')).to be_present
  end

  it 'gives the saved address its saved position back, without a request' do
    session = ChargingSession.create!(kind: :offsite, origin: :user, car: Car.create!(id: 1), started_at: 2.days.ago, kwh: 10, cost: 5)
    session.update_columns(address: 'DE-12345 Town, Main Street 1', latitude: 50.0, longitude: 8.0) # rubocop:disable Rails/SkipsModelValidations
    allow(Place).to receive(:search)

    # The form carries the position of another address that it checked before
    check(id: session.id, address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Other Street 2', latitude: '51.0', longitude: '7.0')

    expect(html.at_css('input[name="charging_session[latitude]"]')['value']).to eq('50.0')
    expect(field(:address_of_position)['value']).to eq('DE-12345 Town, Main Street 1')
    expect(Place).not_to have_received(:search)
  end

  describe 'once the form of a saved session opened' do
    let(:session) do
      ChargingSession.create!(kind: :offsite, origin: :user, car: Car.create!(id: 1), started_at: 2.days.ago, kwh: 10, cost: 5)
    end

    it 'offers the address at a position without an address, and the save keeps the position' do
      session.update_columns(latitude: 50.0, longitude: 8.0) # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:address_at).with(50.0, 8.0).and_return('DE-12345 Town, Main Street 1')
      allow(Place).to receive(:search)

      check(id: session.id, opened: '1', address: '', address_of_position: '', latitude: '50.0', longitude: '8.0')
      expect(field(:address)['value']).to eq('DE-12345 Town, Main Street 1')
      hidden = %w[address address_of_position latitude longitude].index_with { field(it)['value'] }
      patch "/cars/charging_sessions/#{session.id}", params: { charging_session: hidden }, as: :turbo_stream

      expect(session.reload).to have_attributes(address: 'DE-12345 Town, Main Street 1', latitude: 50.0, longitude: 8.0)
      expect(Place).not_to have_received(:search)
    end

    it 'gives an address from before its position and its normal form, and saves nothing' do
      session.update_columns(address: 'Main Street 1, 12345 Town') # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:search).with('Main Street 1, 12345 Town').and_return(found_place)

      check(id: session.id, opened: '1', address: 'Main Street 1, 12345 Town')

      expect(field(:address)['value']).to eq('DE-12345 Town, Main Street 1')
      expect(html.at_css('[data-controller="car--map--component"]')['data-car--map--component-cars-value']).to eq([{ places: [[51.0, 7.0, 1]] }].to_json)
      expect(session.reload).to have_attributes(address: 'Main Street 1, 12345 Town', latitude: nil)
    end

    it 'marks an address from before that Nominatim does not find' do
      session.update_columns(address: 'Main Street 1, 12345 Town') # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:search).and_return(nil)

      check(id: session.id, opened: '1', address: 'Main Street 1, 12345 Town')

      expect(field(:address)['class']).to include('input-error')
    end
  end

  it 'is only for the admin' do
    allow(Place).to receive(:search)
    logout

    check(address: 'Main Street 1')

    expect(response).not_to have_http_status(:ok)
    expect(Place).not_to have_received(:search)
  end
end
