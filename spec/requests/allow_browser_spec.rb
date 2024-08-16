describe 'ApplicationController' do
  let(:headers) { { 'HTTP_USER_AGENT' => user_agent } }

  context 'when using an outdated browser' do
    let(:user_agent) { 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)' }

    it 'returns a 406 status code' do
      get('/', headers:)

      expect(response).to have_http_status(:not_acceptable)
    end
  end

  context 'when using a modern browser' do
    let(:user_agent) do
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15'
    end

    it 'returns a 302 status code' do
      get('/', headers:)

      expect(response).to have_http_status(:redirect)
    end
  end
end
