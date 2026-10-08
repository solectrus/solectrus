# The lists and the frames below the car page follow the car page: the
# settings can switch it off, and a sponsorship opens it (see CarPageGate)
describe 'Car page gate' do
  let(:frame) { { 'Turbo-Frame' => Car::Location::Component::FRAME_ID } }

  before { login_as_admin }

  context 'without the car page' do
    before { Setting.enable_car = false }
    after { Setting.enable_car = true }

    it 'sends a list to the home page' do
      get cars_charging_sessions_path(kind: 'offsite')

      expect(response).to redirect_to(root_path)
    end

    it 'answers no frame' do
      get(cars_location_path(car: 1), headers: frame)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers no stats' do
      get cars_stats_path(timeframe: 'now'), headers: { 'Turbo-Frame' => 'stats' }

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'without a sponsorship' do
    before { allow(ApplicationPolicy.instance).to receive(:feature_enabled?).and_return(false) }

    it 'sends a list to the car page with its upsell' do
      get cars_visits_path

      expect(response).to redirect_to(cars_home_path)
    end

    it 'answers no frame' do
      get(cars_place_path(car: 1), headers: frame)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers no tooltip of a place' do
      place = Place.create!(latitude: 50.9, longitude: 6.4)
      get cars_place_tooltip_path(place:, timeframe: 'all')

      expect(response).to have_http_status(:not_found)
    end
  end
end
