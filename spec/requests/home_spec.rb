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
  end
end
