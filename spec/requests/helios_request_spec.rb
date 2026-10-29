# The menu item of HELIOS leads to /helios, which asks HELIOS for its URL
describe 'HELIOS' do
  before { allow(HeliosCheck).to receive(:skip_http?).and_return(false) }

  it 'redirects to the URL that HELIOS reports' do
    stub_request(:get, 'http://helios:3000/up').to_return(
      status: 200,
      headers: { 'X-Browser-Url' => 'http://192.168.1.10:3999' },
    )

    get '/helios'

    expect(response).to redirect_to('http://192.168.1.10:3999')
  end

  it 'redirects to the host of the request without an answer of HELIOS' do
    stub_request(:get, 'http://helios:3000/up').to_timeout

    get '/helios'

    expect(response).to redirect_to('http://www.example.com:3999')
  end
end
