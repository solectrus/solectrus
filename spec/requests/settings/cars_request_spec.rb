describe 'Settings cars' do
  context 'when logged in as admin' do
    before { login_as_admin }

    describe 'GET /settings/cars' do
      it 'lists the car of each configured number' do
        get settings_cars_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Car 1')
        expect(response.body).not_to include('Trabant:soc')
      end

      context 'with two cars' do
        before do
          Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer'))
          Current.cars = nil
          Car.configured.each { it.update!(name: "Model #{it.id}", active_from: Date.new(it.id + 2020, 1, 1)) }
        end

        after { Sensor::Config.setup(ENV) }

        it 'lists the newest car first' do
          get settings_cars_path

          expect(response.body.index('Model 2')).to be < response.body.index('Model 1')
        end
      end
    end

    describe 'GET /settings/cars/:id/edit' do
      it 'renders the form with the sensors of the car' do
        get edit_settings_car_path(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('sensors.car_roles.car_battery_soc'), 'Trabant:soc')
      end
    end

    describe 'PATCH /settings/cars/:id' do
      it 'saves the name, the short name, the period and the color' do
        patch settings_car_path(1),
              params: { car: { name: 'Model Y', short_name: 'MY', active_from: '2024-03-01', active_until: '', color: '#FF0000' } },
              as: :turbo_stream

        expect(Car.find(1)).to have_attributes(name: 'Model Y', short_name: 'MY', active_from: Date.new(2024, 3, 1), color: '#ff0000')
        expect(response.body).to include('Model Y')
      end

      it 'saves the battery capacity' do
        patch '/settings/cars/1', params: { car: { battery_kwh: '77.5' } }

        expect(Car.find(1).battery_kwh).to eq(77.5)
      end

      it 'stores no color of its own for the default color' do
        patch settings_car_path(1), params: { car: { color: Car::DEFAULT_COLOR } }, as: :turbo_stream

        expect(Car.find(1).color).to be_nil
      end

      it 'refuses an empty short name' do
        patch settings_car_path(1), params: { car: { name: 'Model Y', short_name: ' ' } }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(Car.find(1).name).to be_nil
      end

      it 'renders the form again with an error' do
        patch settings_car_path(1),
              params: { car: { active_from: '2024-03-01', active_until: '2024-02-01' } },
              as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'renders the page of the form again without Turbo Streams' do
        patch settings_car_path(1), params: { car: { name: 'Model Y', short_name: ' ' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq('text/html')
        expect(response.body).to include('<form')
      end

      it 'refuses an empty first day' do
        patch settings_car_path(1), params: { car: { active_from: '' } }, as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
        expect(Car.find(1).active_from).to eq(Rails.configuration.x.installation_date)
      end
    end
  end

  context 'when not logged in' do
    it 'refuses the page' do
      get settings_cars_path

      expect(response).not_to have_http_status(:ok)
    end
  end
end
