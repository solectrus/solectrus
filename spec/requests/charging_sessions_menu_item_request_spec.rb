# The menu links to the list of the charging sessions while the car page is
# open
describe 'Charging sessions menu item' do
  let(:links) { response.parsed_body.css('a[href^="/cars/charging_sessions/"]') }

  context 'when logged in as admin' do
    before { login_as_admin }

    it 'links to the list' do
      get '/power_balance/now'

      expect(links).to be_present
    end

    it 'leaves out the car and the timeframe of the car page' do
      Car.create!(id: 1, name: 'Trabant')
      get cars_home_path(sensor_name: 'car_charging', timeframe: '2026-06', car: 1)

      expect(response).to have_http_status(:success)
      expect(links).to be_present
    end

    context 'without the car page' do
      before { Setting.enable_car = false }
      after { Setting.enable_car = true }

      it 'has no link' do
        get '/power_balance/now'

        expect(links).to be_empty
      end
    end

    context 'without a car' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_CAR_BATTERY_SOC')) }
      after { Sensor::Config.setup(ENV) }

      it 'has no link and no car page' do
        get '/power_balance/now'

        expect(links).to be_empty
        expect(response.parsed_body.css('a[href^="/cars"]')).to be_empty
      end

      it 'has no settings of the cars' do
        get settings_prices_path(name: 'electricity')

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.css('a[href="/settings/cars"]')).to be_empty
      end
    end
  end

  context 'when not logged in' do
    it 'links to the list' do
      get '/power_balance/now'

      expect(links).to be_present
    end

    it 'shows the list without the forms' do
      allow(Car::Report).to receive(:pending_days).and_return([])
      get '/cars/charging_sessions/wallbox/all'

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('/cars/charging_sessions/new')
    end
  end
end
