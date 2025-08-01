describe UpdateCheck::HttpClient do
  subject(:http_client) { described_class.new }

  let(:update_url) { 'https://update.solectrus.de' }

  before { allow(Rails.logger).to receive(:info) }

  describe '#fetch_update_data' do
    subject(:result) { http_client.fetch_update_data }

    context 'when the request succeeds' do
      let(:response_body) do
        { version: 'v0.20.1', registration_status: 'unregistered' }.to_json
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
          data: {
            version: 'v0.20.1',
            registration_status: 'unregistered',
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
          'SOLECTRUS/v1.0.0 (Test)',
        )

        result

        expect(WebMock).to have_requested(:get, update_url).with(
          headers: {
            'Accept' => 'application/json',
            'User-Agent' => 'SOLECTRUS/v1.0.0 (Test)',
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
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs the error' do
        result

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: Error 500 - Internal Server Error',
        )
      end
    end

    context 'when the request times out' do
      before do
        stub_request(:get, update_url).to_timeout
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs the timeout error' do
        result

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed with timeout: execution expired',
        )
      end
    end

    context 'when SSL verification fails' do
      before do
        stub_request(:get, update_url).to_raise(
          OpenSSL::SSL::SSLError.new('SSL verification failed'),
        )
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs the SSL error' do
        result

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed with SSL error: SSL verification failed',
        )
      end
    end

    context 'when JSON parsing fails' do
      before do
        stub_request(:get, update_url).to_return(
          status: 200,
          body: 'invalid json',
        )
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs the JSON error' do
        result

        expect(Rails.logger).to have_received(:error).with(/UpdateCheck failed/)
      end
    end

    context 'when response JSON is invalid format' do
      let(:response_body) { { foo: 'bar' }.to_json }

      before do
        stub_request(:get, update_url).to_return(
          status: 200,
          body: response_body,
        )
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs invalid response error' do
        result

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: Invalid response',
        )
      end
    end

    context 'when an unexpected error occurs' do
      before do
        stub_request(:get, update_url).to_raise(
          StandardError.new('Unexpected error'),
        )
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unknown status with short expiration' do
        expect(result).to eq(
          data: {
            registration_status: 'unknown',
          },
          expires_in: 5.minutes,
        )
      end

      it 'logs the unexpected error' do
        result

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: Unexpected error',
        )
      end
    end
  end
end
