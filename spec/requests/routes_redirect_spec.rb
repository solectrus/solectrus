describe 'Routing' do
  before { allow(Summary).to receive(:fresh?).and_return(true) }

  describe 'URL shortcuts' do
    it 'accepts /day' do
      get '/house_power/day'
      expect(response).to be_successful
    end

    it 'accepts /week' do
      get '/house_power/week'
      expect(response).to be_successful
    end

    it 'accepts /month' do
      get '/house_power/month'
      expect(response).to be_successful
    end

    it 'accepts /year' do
      get '/house_power/year'
      expect(response).to be_successful
    end
  end

  describe 'redirects' do
    describe 'favicon request' do
      it 'redirects to existing file' do
        get '/favicon.ico'
        expect(response).to redirect_to('/favicon-196.png')
      end
    end
  end
end
