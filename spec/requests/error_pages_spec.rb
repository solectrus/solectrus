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

  describe 'error 406' do
    it 'renders a custom 406 error page' do
      without_detailed_exceptions do
        get '/',
            headers: {
              'HTTP_USER_AGENT' =>
                'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
            }
      end

      expect(response).to have_http_status(:not_acceptable)
      expect(response.body).to include(I18n.t('errors.406.title'))
      expect(response.body).to include(I18n.t('errors.unsupported_browser'))
    end
  end

  describe 'error 500' do
    let(:failing_controller) { instance_double(HomeController) }

    before do
      allow(HomeController).to receive(:new).and_return(failing_controller)
      allow(failing_controller).to receive(:index).and_raise('fail')
    end

    it 'renders a custom 500 error page' do
      without_detailed_exceptions { get '/' }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include(I18n.t('errors.500.title'))
    end
  end
end
