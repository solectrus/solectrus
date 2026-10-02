describe 'Settings cars' do
  context 'when logged in as admin' do
    before { login_as_admin }

    describe 'GET /settings/cars' do
      it 'lists the car of each configured number' do
        get settings_cars_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Car 1', I18n.t('settings.cars.never_removed'))
      end
    end

    describe 'GET /settings/cars/:id/edit' do
      it 'renders the form' do
        get edit_settings_car_path(1)

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /settings/cars/:id' do
      it 'saves the name, the period and the color' do
        patch settings_car_path(1),
              params: { car: { name: 'Model Y', active_from: '2024-03-01', active_until: '', color: '#FF0000' } },
              as: :turbo_stream

        expect(Car.find(1)).to have_attributes(name: 'Model Y', active_from: Date.new(2024, 3, 1), color: '#ff0000')
        expect(response.body).to include('Model Y')
      end

      it 'stores no color of its own for the default color' do
        patch settings_car_path(1), params: { car: { color: Car.default_color(1) } }, as: :turbo_stream

        expect(Car.find(1).color).to be_nil
      end

      it 'renders the form again with an error' do
        patch settings_car_path(1),
              params: { car: { active_from: '2024-03-01', active_until: '2024-02-01' } },
              as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
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
