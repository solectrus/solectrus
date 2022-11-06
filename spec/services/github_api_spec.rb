describe GithubApi do
  subject(:api) { described_class.new }

  describe '#latest_release' do
    subject { api.latest_release }

    context 'when the request succeeds', vcr: { cassette_name: 'github' } do
      it { is_expected.to include({ 'tag_name' => 'v0.6.1' }) }
    end

    context 'when the request fails' do
      before do
        stub_request(
          :get,
          'https://api.github.com/repos/solectrus/solectrus/releases/latest',
        ).to_return(status: [500, 'Internal Server Error'])
      end

      it { is_expected.to be_empty }
    end
  end
end
