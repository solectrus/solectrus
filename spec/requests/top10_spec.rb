describe 'Top 10' do
  describe 'GET /top10' do
    it_behaves_like 'localized request', '/top10/day/inverter_power/desc'
  end

  describe 'redirection' do
    it 'redirects top10 when calc is missing' do
      get '/top10/year/house_power/desc'
      expect(response).to redirect_to('/top10/year/house_power/sum/desc')
    end

    it 'redirects top10 when sort is missing' do
      get '/top10/year/house_power'
      expect(response).to redirect_to('/top10/year/house_power/sum/desc')
    end

    it 'redirects top10 when sensor is missing' do
      get '/top10/year/'
      expect(response).to redirect_to('/top10/year/inverter_power/sum/desc')
    end

    it 'redirects top10 when all is missing' do
      get '/top10/'
      expect(response).to redirect_to('/top10/day/inverter_power/sum/desc')
    end
  end
end
