# The menu item of HELIOS leads to /helios, which asks HELIOS for its URL
describe 'HELIOS' do
  before { allow(HeliosCheck).to receive(:skip_http?).and_return(false) }

  def helios_answers(headers)
    stub_request(:get, 'http://helios:3000/up').to_return(status: 200, headers: { 'X-Version' => '1.5.4', **headers })
  end

  it 'redirects to the URL that HELIOS reports' do
    helios_answers('X-Browser-Url' => 'http://192.168.1.10:3999')

    get '/helios'

    expect(response).to redirect_to('http://192.168.1.10:3999')
  end

  it 'redirects to the host of the request when HELIOS reports no URL' do
    helios_answers({})

    get '/helios'

    expect(response).to redirect_to('http://www.example.com:3999')
  end

  describe 'without HELIOS' do
    before { stub_request(:get, 'http://helios:3000/up').to_timeout }

    let(:tracking) { 'utm_campaign=main-nav&utm_content=helios&utm_medium=referral&utm_source=solectrus-app' }

    it 'redirects to the installation' do
      get '/helios'

      expect(response).to redirect_to("https://solectrus.de/install/en/?#{tracking}")
    end

    it 'redirects to the installation in the language of the browser' do
      get '/helios', headers: { 'Accept-Language' => 'de' }

      expect(response).to redirect_to("https://solectrus.de/install/?#{tracking}")
    end
  end

  # The cache can hold "no HELIOS" from before HELIOS started
  it 'asks HELIOS again at the click' do
    Rails.cache.write('HeliosCheck:version', false)
    helios_answers('X-Browser-Url' => 'http://192.168.1.10:3999')

    get '/helios'

    expect(response).to redirect_to('http://192.168.1.10:3999')
  end
end
