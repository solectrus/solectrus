describe 'Web app manifest' do
  # rubocop:disable-next Rails/ResponseParsedBody -- Rails does not treat
  # application/manifest+json as JSON, so parsed_body returns the raw body.
  let(:json) { JSON.parse(response.body) }

  it_behaves_like 'localized request', '/manifest.webmanifest'

  context 'without a language preference' do
    before { get '/manifest.webmanifest' }

    it 'responds with the manifest media type' do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/manifest+json')
    end

    it 'takes the theme color from ThemeConfig' do
      expect(json['theme_color']).to eq(ThemeConfig::LIGHT_COLOR)
      expect(json['background_color']).to eq(ThemeConfig::LIGHT_COLOR)
    end

    it 'describes the installable app' do
      expect(json).to include(
        'id' => 'solectrus',
        'name' => 'SOLECTRUS',
        'start_url' => '/',
        'display' => 'standalone',
      )
    end

    it 'offers an icon for each size and purpose' do
      expect(
        json['icons'].map { |icon| [icon['sizes'], icon['purpose']] },
      ).to eq(
        [
          %w[192x192 any],
          %w[192x192 maskable],
          %w[512x512 any],
          %w[512x512 maskable],
        ],
      )
    end

    it 'points to icons that exist' do
      json['icons'].each do |icon|
        expect(Rails.public_path.join(icon['src'].delete_prefix('/'))).to exist
      end
    end

    it 'falls back to the default locale' do
      expect(json['lang']).to eq('en')
      expect(json['description']).to eq('Photovoltaic Dashboard')
    end

    # A shared cache must not hand the language of one visitor to the next.
    it 'keeps the answer out of shared caches' do
      expect(response.headers['Cache-Control']).to eq('max-age=3600, private')
      # Rack appends its own values (Accept-Encoding, Origin) to this header.
      expect(response.headers['Vary'].split(', ')).to include('Accept-Language')
    end
  end

  context 'when the browser asks for German' do
    before do
      get '/manifest.webmanifest', headers: { 'Accept-Language' => 'de-DE' }
    end

    it 'answers in German' do
      expect(json['lang']).to eq('de')
      expect(json['description']).to eq('Photovoltaik-Dashboard')
    end
  end

  context 'when the visitor picked a language' do
    before do
      get '/manifest.webmanifest',
          headers: {
            'Accept-Language' => 'en-US',
            'Cookie' => 'locale=de',
          }
    end

    it 'prefers the chosen language over the browser header' do
      expect(json['lang']).to eq('de')
      expect(json['description']).to eq('Photovoltaik-Dashboard')
    end
  end
end
