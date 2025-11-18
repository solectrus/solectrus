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
  end
end
