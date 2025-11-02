describe 'Health Check' do
  context 'when all systems are up' do
    it 'returns 200' do
      get '/up'

      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['postgresql']).to eq('ok')
      expect(json['redis']).to be_nil # Redis not used in tests
      expect(json['influxdb']).to eq('ok')
      expect(json['version']).to be_present
    end
  end

  context 'when PostgreSQL is down' do
    before do
      allow(ApplicationRecord.connection).to receive(:select_value).and_raise(
        StandardError,
      )
    end

    it 'returns 503' do
      get '/up'

      expect(response).to have_http_status(:service_unavailable)

      json = response.parsed_body
      expect(json['postgresql']).to eq('error')
      expect(json['redis']).to be_nil # Redis not used in tests
      expect(json['influxdb']).to eq('ok')
      expect(json['version']).to be_present
    end
  end
end
