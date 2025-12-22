describe 'Home' do
  describe 'GET /' do
    it_behaves_like 'localized request', '/'
    it_behaves_like 'sponsoring redirects', '/'

    context 'without params :fields and :timeframe' do
      context 'when day' do
        before do
          allow(Sensor::Query::DayLight).to receive(:active?).and_return(true)
        end

        it 'redirects' do
          get balance_home_path
          expect(response).to redirect_to(
            balance_home_path(sensor_name: 'inverter_power', timeframe: 'now'),
          )
        end
      end

      context 'when night' do
        before do
          allow(Sensor::Query::DayLight).to receive(:active?).and_return(false)
        end

        it 'redirects' do
          get balance_home_path
          expect(response).to redirect_to(
            balance_home_path(sensor_name: 'house_power', timeframe: 'now'),
          )
        end
      end
    end

    context 'without param :timeframe' do
      it 'redirects' do
        get balance_home_path(sensor_name: 'house_power')
        expect(response).to redirect_to(
          balance_home_path(sensor_name: 'house_power', timeframe: 'now'),
        )
      end
    end

    context 'with params :sensor and :timeframe' do
      it 'renders' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: Date.yesterday.strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when param :timeframe is in the future' do
      it 'redirects to forecast for day' do
        get balance_home_path(
              timeframe: (Date.current + 2.days).strftime('%Y-%m-%d'),
              sensor_name: 'inverter_power',
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for week' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.week).strftime('%G-W%V'),
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for month' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.month).strftime('%Y-%m'),
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for year' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.year).strftime('%Y'),
            )
        expect(response).to redirect_to(forecast_path)
      end
    end

    context 'when timeframe is before installation date' do
      it 'renders for day' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.day
                ).strftime('%Y-%m-%d'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for week' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.week
                ).strftime('%Y-W%V'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for month' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.month
                ).strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for year' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.year
                ).strftime('%Y'),
            )
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
