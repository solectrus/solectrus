describe 'Home', vcr: { cassette_name: 'version' } do
  describe 'GET /' do
    context 'without params' do
      it 'redirects' do
        get root_path
        expect(response).to redirect_to(
          root_path(field: 'inverter_power', timeframe: 'now'),
        )
      end
    end

    context 'with field' do
      it 'renders' do
        get root_path(field: 'house_power')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with field and timeframe' do
      it 'renders' do
        get root_path(
              field: 'house_power',
              timeframe: Date.yesterday.strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when timeframe is in the future' do
      it 'fails for day' do
        expect do
          get root_path(
                timeframe: (Date.current + 2.days).strftime('%Y-%m-%d'),
                field: 'house_power',
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for week' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe: (Date.current + 1.week).strftime('%Y-W%V'),
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for month' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe: (Date.current + 1.month).strftime('%Y-%m'),
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for year' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe: (Date.current + 1.year).strftime('%Y'),
              )
        end.to raise_error(ActionController::RoutingError)
      end
    end

    context 'when timeframe is before installation date' do
      it 'fails for day' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe:
                  (
                    Rails.configuration.x.installation_date.beginning_of_year -
                      1.day
                  ).strftime('%Y-%m-%d'),
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for week' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe:
                  (
                    Rails.configuration.x.installation_date.beginning_of_year -
                      1.week
                  ).strftime('%Y-W%V'),
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for month' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe:
                  (
                    Rails.configuration.x.installation_date.beginning_of_year -
                      1.month
                  ).strftime('%Y-%m'),
              )
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for year' do
        expect do
          get root_path(
                field: 'house_power',
                timeframe:
                  (
                    Rails.configuration.x.installation_date.beginning_of_year -
                      1.year
                  ).strftime('%Y'),
              )
        end.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
