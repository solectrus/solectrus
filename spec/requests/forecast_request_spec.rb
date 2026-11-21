describe 'Forecast' do
  describe 'GET /forecast' do
    # The pages the arrows lead to, on a desktop and on a phone
    def nav_targets(direction)
      response.parsed_body.css("a[data-nav=#{direction}]").pluck('href').uniq
    end

    let(:availability_query) do
      instance_double(Sensor::Query::ForecastAvailability)
    end

    before do
      allow(Sensor::Query::ForecastAvailability).to receive(:new).and_return(
        availability_query,
      )
      allow(availability_query).to receive(:call).and_return(
        Date.current + 6.days,
      )
    end

    it_behaves_like 'localized request', '/forecast'
    it_behaves_like 'sponsoring redirects', '/forecast'

    context 'when HTML request' do
      it 'renders the page' do
        get forecast_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes turbo frames for navigation and charts' do
        get forecast_path
        expect(response.body).to include('turbo-frame id="forecast-timeframe"')
        expect(response.body).to include(
          'turbo-frame id="inverter-power-forecast-chart"',
        )
        expect(response.body).to include(
          'turbo-frame id="outdoor-temp-forecast-chart"',
        )
      end

      it 'enables swipe controller for navigation' do
        get forecast_path
        expect(response.body).to match(/data-controller="[^"]*swipe/)
      end

      it 'includes prev link for backward navigation' do
        get forecast_path
        expect(response.body).to include('data-nav="prev"')
      end

      it 'shows today and tomorrow, with a way to all days' do
        get forecast_path

        expect(response.body).to include(I18n.t('forecast.today_and_tomorrow'))
        expect(response.body).to include(forecast_chart_path(:inverter_power, days: 2))
        expect(nav_targets('next')).to eq([forecast_all_path])
      end
    end

    context 'when all days are requested' do
      it 'shows all days, with the way back to today and tomorrow' do
        get forecast_all_path

        expect(response.body).to include(I18n.t('forecast.next_days', count: 7))
        expect(response.body).to include(forecast_chart_path(:inverter_power, days: 7))
        expect(nav_targets('prev')).to eq([forecast_path])
        expect(nav_targets('next')).to be_empty
      end

      it 'leads to today and tomorrow when the forecast has no more days' do
        allow(availability_query).to receive(:call).and_return(Date.current + 1.day)

        get forecast_all_path

        expect(response).to redirect_to(forecast_path)
      end
    end

    context 'when turbo_frame request to inverter power chart' do
      it 'renders turbo_stream response' do
        get forecast_chart_path(id: 'inverter_power'),
            headers: {
              'Turbo-Frame' => 'inverter-power-forecast-chart',
            }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates chart frame' do
        get forecast_chart_path(id: 'inverter_power'),
            headers: {
              'Turbo-Frame' => 'inverter-power-forecast-chart',
            }
        expect(response.body).to include('turbo-stream action="update"')
        expect(response.body).to include(
          'target="inverter-power-forecast-chart"',
        )
      end
    end

    context 'when turbo_frame request to outdoor temp chart' do
      it 'renders turbo_stream response' do
        get forecast_chart_path(id: 'outdoor_temp'),
            headers: {
              'Turbo-Frame' => 'outdoor-temp-forecast-chart',
            }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates outdoor temp chart frame' do
        get forecast_chart_path(id: 'outdoor_temp'),
            headers: {
              'Turbo-Frame' => 'outdoor-temp-forecast-chart',
            }
        expect(response.body).to include('turbo-stream action="update"')
        expect(response.body).to include('target="outdoor-temp-forecast-chart"')
      end
    end
  end
end
