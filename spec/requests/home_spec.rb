describe 'Home', vcr: { cassette_name: 'version' } do
  describe 'GET /' do
    it_behaves_like 'localized request', '/'

    context 'without params :fields and :timeframe' do
      context 'when day' do
        before { allow(DayLight).to receive(:active?).and_return(true) }

        it 'redirects' do
          get root_path
          expect(response).to redirect_to(
            root_path(field: 'inverter_power', timeframe: 'now'),
          )
        end
      end

      context 'when night' do
        before { allow(DayLight).to receive(:active?).and_return(false) }

        it 'redirects' do
          get root_path
          expect(response).to redirect_to(
            root_path(field: 'house_power', timeframe: 'now'),
          )
        end
      end
    end

    context 'without param :timeframe' do
      it 'redirects' do
        get root_path(field: 'house_power')
        expect(response).to redirect_to(
          root_path(field: 'house_power', timeframe: 'now'),
        )
      end
    end

    context 'with params :field and :timeframe' do
      it 'renders' do
        get root_path(
              field: 'house_power',
              timeframe: Date.yesterday.strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when param :timeframe is in the future' do
      it 'renders for day' do
        get root_path(
              timeframe: (Date.current + 2.days).strftime('%Y-%m-%d'),
              field: 'house_power',
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for week' do
        get root_path(
              field: 'house_power',
              timeframe: (Date.current + 1.week).strftime('%Y-W%V'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for month' do
        get root_path(
              field: 'house_power',
              timeframe: (Date.current + 1.month).strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for year' do
        get root_path(
              field: 'house_power',
              timeframe: (Date.current + 1.year).strftime('%Y'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when timeframe is before installation date' do
      it 'renders for day' do
        get root_path(
              field: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.day
                ).strftime('%Y-%m-%d'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for week' do
        get root_path(
              field: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.week
                ).strftime('%Y-W%V'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for month' do
        get root_path(
              field: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.month
                ).strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for year' do
        get root_path(
              field: 'house_power',
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
