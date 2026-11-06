describe FontPreload::Component, type: :component do
  subject(:component) { described_class.new }

  context 'when the dev server runs' do
    before do
      allow(RailsVite.config).to receive(:dev_server_running?).and_return(true)

      render_inline(component)
    end

    it 'renders nothing' do
      expect(page).to have_no_css('link', visible: :all)
    end
  end

  context 'when the assets are built' do
    before do
      allow(RailsVite.config).to receive(:dev_server_running?).and_return(
        false,
      )

      render_inline(component)
    end

    it 'preloads the font from the manifest' do
      expect(page).to have_css(
        "link[rel='preload'][as='font'][type='font/woff2']",
        visible: :all,
      )
    end

    # A font is fetched in CORS mode even when it is same-origin. Without the
    # attribute the preload does not match that fetch, and the browser
    # downloads the font twice.
    it 'marks the preload crossorigin' do
      expect(page).to have_css(
        "link[rel='preload'][crossorigin='anonymous']",
        visible: :all,
      )
    end

    it 'points at the hashed file the stylesheet uses' do
      href = page.find("link[rel='preload']", visible: :all)[:href]

      expect(href).to match(%r{\A/vite.*/inter-latin-wght-normal-.*\.woff2\z})
    end
  end

  # A build without the font leaves the page working, only without the hint.
  context 'when the manifest lacks the font' do
    before do
      allow(RailsVite.config).to receive(:dev_server_running?).and_return(
        false,
      )
      allow(RailsVite.manifest).to receive(:path_for).with(
        described_class::FONT,
      ).and_raise(RailsVite::MissingEntryError.new(described_class::FONT, 'manifest.json'))

      render_inline(component)
    end

    it 'renders nothing' do
      expect(page).to have_no_css('link', visible: :all)
    end
  end
end
