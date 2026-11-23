describe ImmutableAssets do
  subject(:middleware) { described_class.new(app) }

  let(:status) { 200 }
  let(:app) { ->(_env) { [status, { 'cache-control' => 'default' }, ['OK']] } }
  let(:a_year) { 'public, s-maxage=31556952, max-age=31556952, immutable' }
  let(:prefix) { RailsVite.config.asset_prefix }

  def cache_control(path)
    _, headers, = middleware.call(Rack::MockRequest.env_for(path))
    headers['cache-control']
  end

  it 'keeps a digested Vite asset for a year' do
    expect(cache_control("#{prefix}/assets/application-Dx4kXJAl.js")).to eq(a_year)
  end

  it 'keeps the default for another file in public/' do
    expect(cache_control('/apple-splash-1170-2532.png')).to eq('default')
  end

  it 'keeps the default for a file that dot segments lead out of the assets' do
    expect(cache_control("#{prefix}/assets/%2e%2e/manifest.json")).to eq('default')
  end

  it 'keeps a digested Vite asset behind a double slash for a year' do
    expect(cache_control("#{prefix}//assets/application-Dx4kXJAl.js")).to eq(a_year)
  end

  context 'when a range of the asset is requested' do
    let(:status) { 206 }

    it 'keeps it for a year' do
      expect(cache_control("#{prefix}/assets/application-Dx4kXJAl.js")).to eq(a_year)
    end
  end

  context 'when the asset is missing' do
    let(:status) { 404 }

    it 'keeps the default' do
      expect(cache_control("#{prefix}/assets/missing.js")).to eq('default')
    end
  end
end
