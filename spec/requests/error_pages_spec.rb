describe 'Error pages', vcr: { cassette_name: 'version' } do
  describe 'error 404' do
    it 'renders a custom 404 error page' do
      without_detailed_exceptions { get '/non-existing-route' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.404.title'))
    end

    it 'ignores given format' do
      without_detailed_exceptions { get '/ads.txt' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.404.title'))
    end
  end

  describe 'error 500' do
    let(:failing_controller) { instance_double(Balance::HomeController) }

    before do
      allow(Balance::HomeController).to receive(:new).and_return(
        failing_controller,
      )
      allow(failing_controller).to receive(:index).and_raise('fail')
    end

    it 'renders a custom 500 error page' do
      without_detailed_exceptions { get '/' }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include(I18n.t('errors.500.title'))
    end
  end
end
