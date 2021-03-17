describe 'Home' do
  describe 'GET /' do
    context 'without params' do
      it 'redirects' do
        get root_path
        expect(response).to redirect_to(root_path(timeframe: 'now', field: 'inverter_power'))
      end
    end

    context 'with timeframe only' do
      it 'redirects' do
        get root_path(timeframe: 'now')
        expect(response).to redirect_to(root_path(timeframe: 'now', field: 'inverter_power'))
      end
    end

    context 'with timeframe and field only' do
      it 'renders' do
        get root_path(timeframe: 'now', field: 'house_power')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with timeframe, field and timestamp' do
      it 'renders' do
        get root_path(timeframe: 'now', field: 'house_power', timestamp: Date.yesterday)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when timestamp is in the future' do
      it 'fails for day' do
        expect do
          get root_path(timeframe: 'day', field: 'house_power', timestamp: Date.current + 2.days)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for week' do
        expect do
          get root_path(timeframe: 'week', field: 'house_power', timestamp: Date.current + 1.week)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for month' do
        expect do
          get root_path(timeframe: 'month', field: 'house_power', timestamp: Date.current + 1.month)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for year' do
        expect do
          get root_path(timeframe: 'year', field: 'house_power', timestamp: Date.current + 1.year)
        end.to raise_error(ActionController::RoutingError)
      end
    end

    context 'when timestamp is before installation date' do
      it 'fails for day' do
        expect do
          get root_path(timeframe: 'day', field: 'house_power', timestamp: Rails.configuration.x.installation_date.beginning_of_year - 1.day)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for week' do
        expect do
          get root_path(timeframe: 'week', field: 'house_power', timestamp: Rails.configuration.x.installation_date.beginning_of_year - 1.week)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for month' do
        expect do
          get root_path(timeframe: 'month', field: 'house_power', timestamp: Rails.configuration.x.installation_date.beginning_of_year - 1.month)
        end.to raise_error(ActionController::RoutingError)
      end

      it 'fails for year' do
        expect do
          get root_path(timeframe: 'year', field: 'house_power', timestamp: Rails.configuration.x.installation_date.beginning_of_year - 1.year)
        end.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
