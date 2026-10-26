describe 'Top 10 Chart' do
  describe 'GET /top10-chart' do
    context 'with valid aggregation' do
      it 'renders successfully for sum aggregation' do
        get '/top10-chart/day/grid_costs/sum/desc'
        expect(response).to have_http_status(:success)
      end
    end

    context 'with invalid aggregation' do
      it 'returns not found for max aggregation on grid_costs' do
        get '/top10-chart/day/grid_costs/max/desc'
        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for max aggregation on custom_power' do
        get '/top10-chart/week/custom_power_03/max/desc'
        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for avg aggregation on grid_costs' do
        get '/top10-chart/month/grid_costs/avg/asc'
        expect(response).to have_http_status(:not_found)
      end
    end

    # A car tells when it drove (see Car::AdminOnlyDays)
    context 'with a sensor of a car' do
      before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer')) }
      after { Sensor::Config.setup(ENV) }

      it 'ends the ranking of a guest with the latest public day' do
        allow(Sensor::Query::Ranking).to receive(:new).and_call_original
        get '/top10-chart/day/car_odometer_1/sum/desc'

        expect(response).to have_http_status(:success)
        expect(Sensor::Query::Ranking).to have_received(:new).with(anything, hash_including(stop: Date.current - 2))
      end
    end
  end
end
