describe 'Routes redirection' do
  around do |example|
    travel_to Time.zone.local(2021, 6, 21, 12, 0, 0), &example
  end

  describe 'URL shortcuts' do
    it 'redirects /day' do
      get '/house_power/day'
      expect(response).to redirect_to('/house_power/2021-06-21')
      expect(response).to have_http_status :found
    end

    it 'redirects /week' do
      get '/house_power/week'
      expect(response).to redirect_to('/house_power/2021-W25')
      expect(response).to have_http_status :found
    end

    it 'redirects /month' do
      get '/house_power/month'
      expect(response).to redirect_to('/house_power/2021-06')
      expect(response).to have_http_status :found
    end

    it 'redirects /year' do
      get '/house_power/year'
      expect(response).to redirect_to('/house_power/2021')
      expect(response).to have_http_status :found
    end
  end

  describe 'old routes redirection' do
    it 'redirects top10 when sort is missing' do
      get '/top10/year/house_power'
      expect(response).to redirect_to('/top10/year/house_power/desc')
      expect(response).to have_http_status :moved_permanently
    end
  end

  describe 'favicon request' do
    it 'redirects to existing file' do
      get '/favicon.ico'
      expect(response).to redirect_to('/favicon-196.png')
    end
  end
end
