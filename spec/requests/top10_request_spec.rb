describe 'Top 10' do
  describe 'GET /top10' do
    it_behaves_like 'localized request', '/top10/day/inverter_power/desc'
    it_behaves_like 'sponsoring redirects', '/top10/day/inverter_power/desc'
  end

  describe 'redirection' do
    it 'redirects when calc is missing' do
      get '/top10/year/house_power/desc'
      expect(response).to redirect_to('/top10/year/house_power/sum/desc')
    end

    it 'redirects when sort is missing' do
      get '/top10/year/house_power'
      expect(response).to redirect_to('/top10/year/house_power/sum/desc')
    end

    it 'redirects when sensor is missing' do
      get '/top10/year/'
      expect(response).to redirect_to('/top10/year/inverter_power/sum/desc')
    end

    it 'redirects when all is missing' do
      get '/top10/'
      expect(response).to redirect_to('/top10/day/inverter_power/sum/desc')
    end

    it 'redirects when sensor does not support max (custom power)' do
      get '/top10/week/custom_power_03/max/desc'
      expect(response).to redirect_to('/top10/week/custom_power_03/sum/desc')
    end

    it 'redirects when sensor does not support max (grid_costs)' do
      get '/top10/day/grid_costs/max/desc'
      expect(response).to redirect_to('/top10/day/grid_costs/sum/desc')
    end
  end

  # The page offers only the rankings the installation permits
  it 'returns not found when the sensor needs a sponsorship' do
    stub_feature

    get '/top10/month/heatpump_heating_power/sum/asc'
    expect(response).to have_http_status(:not_found)
  end
end
