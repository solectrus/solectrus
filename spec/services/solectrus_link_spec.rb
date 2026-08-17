describe SolectrusLink do
  describe '.params' do
    subject(:params) { described_class.params(campaign: 'main-nav', content: 'docs') }

    it 'names the app as the one source of every in-app link' do
      expect(params).to eq(
        utm_source: 'solectrus-app',
        utm_medium: 'referral',
        utm_campaign: 'main-nav',
        utm_content: 'docs',
      )
    end

    # A place with a single link needs nothing to tell its links apart, and an
    # empty parameter would only show up as an empty bucket in the report.
    it 'omits the content where a place has one link only' do
      expect(described_class.params(campaign: 'footer')).not_to include(
        :utm_content,
      )
    end
  end

  describe '.url' do
    subject(:url) do
      described_class.url('https://solectrus.de/docs/', campaign: 'main-nav')
    end

    it 'keeps the address and appends the parameters' do
      expect(url).to start_with('https://solectrus.de/docs/?')

      query = Rack::Utils.parse_query(URI.parse(url).query)
      expect(query).to eq(
        'utm_source' => 'solectrus-app',
        'utm_medium' => 'referral',
        'utm_campaign' => 'main-nav',
      )
    end
  end
end
