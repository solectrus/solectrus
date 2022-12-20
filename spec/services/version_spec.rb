describe Version do
  subject(:api) { described_class.new }

  describe '#latest_release' do
    subject { api.latest }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it { is_expected.to eq('v0.7.4') }
    end

    context 'when the request fails' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          status: [500, 'Internal Server Error'],
        )
      end

      it { is_expected.to be_nil }
    end
  end
end
