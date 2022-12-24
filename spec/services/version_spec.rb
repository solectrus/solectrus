describe Version do
  subject(:version) { described_class }

  describe '.latest' do
    subject { version.latest }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it { is_expected.to eq('v0.7.4') }
    end

    context 'when the request fails' do
      before do
        stub_request(:get, Version::CHECK_URL).to_return(
          status: [500, 'Internal Server Error'],
        )
      end

      it { is_expected.to be_nil }
    end

    context 'when the request timeouts' do
      before { stub_request(:get, Version::CHECK_URL).to_timeout }

      it { is_expected.to be_nil }
    end

    context 'when response is invalid', vcr: { cassette_name: 'version' } do
      before { allow(JSON).to receive(:parse).and_raise(JSON::ParserError) }

      it { is_expected.to be_nil }
    end
  end
end
