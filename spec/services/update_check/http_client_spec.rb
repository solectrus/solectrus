describe UpdateCheck::HttpClient do
  subject(:http_client) { described_class.new }

  let(:update_url) { 'https://update.solectrus.de' }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#fetch_update_data' do
    subject(:result) { http_client.fetch_update_data }

    context 'when the request succeeds' do
      include_context 'with signature verification'

      let(:response_body) do
        signed_json(version: 'v1.2.1', registration_status: 'unregistered')
      end
      let(:headers) { { 'Cache-Control' => 'max-age=43200' } }

      before do
        stub_request(:get, update_url).to_return(
          status: 200,
          body: response_body,
          headers:,
        )
      end

      it 'returns the parsed JSON data with expiration' do
        expect(result).to eq(
          status: :ok,
          data: {
            version: 'v1.2.1',
            registration_status: 'unregistered',
            signature: JSON.parse(response_body, symbolize_names: true)[:signature],
          },
          expires_in: 43_200,
        )
      end

      it 'logs successful check' do
        result

        expect(Rails.logger).to have_received(:info).with(
          'Checked for update availability, valid for 720 minutes',
        )
      end

      it 'sends correct headers' do
        allow(UserAgentBuilder.instance).to receive(:to_s).and_return(
          'SOLECTRUS/v1.2.1 (Test)',
        )

        result

        expect(WebMock).to have_requested(:get, update_url).with(
          headers: {
            'Accept' => 'application/json',
            'User-Agent' => 'SOLECTRUS/v1.2.1 (Test)',
          },
        )
      end

      context 'when Cache-Control header is missing' do
        let(:headers) { {} }

        it 'uses default expiration of 12 hours' do
          expect(result[:expires_in]).to eq(12.hours)
        end
      end

      context 'when Cache-Control has different format' do
        let(:headers) do
          { 'Cache-Control' => 'public, max-age=7200, must-revalidate' }
        end

        it 'extracts max-age correctly' do
          expect(result[:expires_in]).to eq(7200)
        end
      end
    end

    context 'when the request fails with HTTP error' do
      before do
        stub_request(:get, update_url).to_return(
          status: [500, 'Internal Server Error'],
        )
      end

      it 'returns an error result' do
        expect(result).to eq(
          status: :error,
          error_message: 'Error 500 - Internal Server Error',
        )
      end
    end

    context 'when the request times out' do
      before { stub_request(:get, update_url).to_timeout }

      it 'returns an error result' do
        expect(result).to eq(
          status: :error,
          error_message: 'timeout: execution expired',
        )
      end
    end

    context 'when SSL verification fails' do
      before do
        stub_request(:get, update_url).to_raise(
          OpenSSL::SSL::SSLError.new('SSL verification failed'),
        )
      end

      it 'returns an error result' do
        expect(result).to eq(
          status: :error,
          error_message: 'SSL error: SSL verification failed',
        )
      end
    end

    context 'when JSON parsing fails' do
      before do
        stub_request(:get, update_url).to_return(
          status: 200,
          body: 'invalid json',
        )
      end

      it 'returns an error result' do
        expect(result[:status]).to eq(:error)
        expect(result[:error_message]).to match(/JSON|unexpected/i)
      end
    end

    context 'when response JSON is invalid format' do
      let(:response_body) { { foo: 'bar' }.to_json }

      before do
        stub_request(:get, update_url).to_return(
          status: 200,
          body: response_body,
        )
      end

      it 'returns an error result' do
        expect(result).to eq(
          status: :error,
          error_message: 'Invalid response',
        )
      end
    end

    context 'when an unexpected error occurs' do
      before do
        stub_request(:get, update_url).to_raise(
          StandardError.new('Unexpected error'),
        )
      end

      it 'returns an error result' do
        expect(result).to eq(
          status: :error,
          error_message: 'Unexpected error',
        )
      end
    end

    context 'when signature verification fails' do
      include_context 'with signature verification'

      let(:response_body) do
        { version: 'v1.2.1', registration_status: 'complete' }.to_json
      end
      let(:headers) { { 'Cache-Control' => 'max-age=43200' } }

      before do
        stub_request(:get, update_url).to_return(
          status: 200, body: response_body, headers:,
        )
      end

      it 'returns an error result' do
        expect(result[:status]).to eq(:error)
        expect(result[:error_message]).to match(/Signature verification failed/)
      end
    end
  end
end
