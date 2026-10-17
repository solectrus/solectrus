describe Place::Nominatim do
  subject(:answer) { described_class.reverse(50.922622, 6.407071) }

  let(:url) { %r{\Ahttps://nominatim\.openstreetmap\.org/reverse\?} }

  context 'with an answer' do
    let(:body) { { name: '', address: { road: 'Main Street', town: 'Jülich' } } }

    before do
      stub_request(:get, url).to_return(body: body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'gives the full answer' do
      expect(answer).to eq(body.deep_stringify_keys)
    end

    it 'asks for the address in the locale, with the name and the version of the app' do
      answer

      expect(
        a_request(:get, url).with(
          query: hash_including('lat' => '50.922622', 'lon' => '6.407071', 'zoom' => '18', 'accept-language' => 'en'),
          headers: {
            'User-Agent' => "SOLECTRUS/#{Rails.configuration.x.git.commit_version} (self-hosted; +https://solectrus.de)",
          },
        ),
      ).to have_been_made.once
    end

    it 'logs the request with its server and its result' do
      allow(Rails.logger).to receive(:info)
      answer

      expect(Rails.logger).to have_received(:info).with(
        /\APlace::Nominatim: nominatim\.openstreetmap\.org for 50\.9226,6\.4071: HTTP 200 in \d+ ms\z/,
      )
    end
  end

  context 'with another server' do
    before do
      allow(Rails.configuration.x).to receive(:nominatim_url).and_return('http://nominatim.local:8080/geo/')
      stub_request(:get, %r{\Ahttp://nominatim\.local:8080/geo/reverse\?}).to_return(body: { address: {} }.to_json)
    end

    it 'asks this server' do
      expect(answer).to eq('address' => {})
    end
  end

  context 'when turned off' do
    before { allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil) }

    it 'asks nothing' do
      expect(answer).to be_nil
      expect(a_request(:any, //)).not_to have_been_made
    end
  end

  context 'with two requests' do
    before do
      stub_const('Place::Nominatim::INTERVAL', 0.2)
      stub_request(:get, url).to_return(body: { address: {} }.to_json)
    end

    it 'keeps the distance between them' do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      2.times { described_class.reverse(50.92, 6.40) }

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be >= 0.2
    end
  end

  context 'with an error of Nominatim' do
    before { stub_request(:get, url).to_return(body: { error: 'Unable to geocode' }.to_json) }

    it { is_expected.to be_nil }

    it 'asks again at once, because the server works' do
      2.times { described_class.reverse(50.92, 6.40) }

      expect(a_request(:get, url)).to have_been_made.twice
    end
  end

  context 'with an error of the server' do
    before { stub_request(:get, url).to_return(status: 429) }

    it { is_expected.to be_nil }

    it 'asks nothing for a while' do
      2.times { described_class.reverse(50.92, 6.40) }

      expect(a_request(:get, url)).to have_been_made.once
    end

    it 'still searches an address' do
      stub_request(:get, %r{/search}).to_return(body: [].to_json)
      described_class.reverse(50.92, 6.40)

      expect(described_class.search('Main Street 1')).to be_nil
    end

    it 'asks again after the pause' do
      stub_const('Place::Nominatim::PAUSE', 0.0)
      2.times { described_class.reverse(50.92, 6.40) }

      expect(a_request(:get, url)).to have_been_made.twice
    end
  end

  context 'without an answer' do
    before { stub_request(:get, url).to_timeout }

    it { is_expected.to be_nil }

    it 'logs the request with its error' do
      allow(Rails.logger).to receive(:info)
      answer

      expect(Rails.logger).to have_received(:info).with(/: Net::OpenTimeout in \d+ ms\z/)
    end

    it 'asks nothing for a while' do
      2.times { described_class.reverse(50.92, 6.40) }

      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe '.search' do
    subject(:answer) { described_class.search('12345 Town, Main Street 1', country_code: 'de') }

    let(:url) { %r{\Ahttps://nominatim\.openstreetmap\.org/search\?} }

    context 'with a match' do
      before do
        stub_request(:get, url).to_return(body: [{ lat: '50.1', lon: '8.2', place_rank: 30 }].to_json)
      end

      it 'gives the best match' do
        expect(answer).to eq('lat' => '50.1', 'lon' => '8.2', 'place_rank' => 30)
      end

      it 'asks for one match in the country, with its address' do
        answer

        expect(
          a_request(:get, url).with(query: hash_including('q' => '12345 Town, Main Street 1', 'countrycodes' => 'de', 'limit' => '1', 'addressdetails' => '1')),
        ).to have_been_made.once
      end

      it 'asks for the names of the country, not of the locale' do
        answer

        expect(a_request(:get, url).with { !it.uri.query_values.key?('accept-language') }).to have_been_made.once
      end

      it 'logs the request without the address' do
        allow(Rails.logger).to receive(:info)
        answer

        expect(Rails.logger).to have_received(:info).with(/\APlace::Nominatim: nominatim\.openstreetmap\.org for an address: HTTP 200 in \d+ ms\z/)
      end
    end

    context 'without a country' do
      before { stub_request(:get, url).to_return(body: [].to_json) }

      it 'searches each country' do
        described_class.search('Town')

        expect(a_request(:get, url).with { !it.uri.query_values.key?('countrycodes') }).to have_been_made.once
      end
    end

    context 'without a match' do
      before { stub_request(:get, url).to_return(body: [].to_json) }

      it { is_expected.to be_nil }
    end

    context 'with an error of the server' do
      before { stub_request(:get, url).to_return(status: 429) }

      it 'raises, because the address can exist' do
        expect { answer }.to raise_error(described_class::Unavailable)
      end
    end

    context 'when turned off' do
      before { allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil) }

      it 'raises' do
        expect { answer }.to raise_error(described_class::Unavailable)
      end
    end
  end
end
