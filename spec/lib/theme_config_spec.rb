describe ThemeConfig do
  # .setup writes to Rails.application.config, which every other spec reads
  # through ThemeConfig.x. Put the original back, or the theme of the last
  # example here leaks into whatever runs next.
  around do |example|
    original = Rails.application.config.theme
    example.run
    Rails.application.config.theme = original
  end

  let(:theme_config) { described_class.new(theme) }

  let(:env_light) { { 'UI_THEME' => 'light' } }
  let(:env_dark) { { 'UI_THEME' => 'dark' } }

  context 'when the ApplicationPolicy does not allow themes' do
    before { allow(ApplicationPolicy).to receive(:themes?).and_return(false) }

    describe '.setup' do
      before { described_class.setup(env_dark) }

      it 'ignores the given theme' do
        expect(Rails.application.config.theme).not_to be_static
      end

      it 'returns the light color' do
        expect(Rails.application.config.theme.color).to eq('#4f46e5')
      end

      it 'ignores the choice of the visitor' do
        expect(Rails.application.config.theme.color('dark')).to eq('#4f46e5')
        expect(Rails.application.config.theme.auto?('dark')).to be(false)
      end
    end
  end

  context 'when the ApplicationPolicy allows themes' do
    before { allow(ApplicationPolicy).to receive(:themes?).and_return(true) }

    describe '.setup' do
      before { described_class.setup(env_light) }

      it 'sets up the theme configuration' do
        expect(Rails.application.config.theme).to be_an_instance_of(
          described_class,
        )
      end
    end

    describe '.x' do
      subject { described_class.x }

      before { described_class.setup(env_light) }

      it { is_expected.to be_an_instance_of(described_class) }
    end

    shared_examples 'a valid theme' do |color:, static:, html_class:|
      it 'returns the correct color' do
        expect(theme_config.color).to eq(color)
      end

      it 'returns the correct static status' do
        expect(theme_config.static?).to be(static)
      end

      it 'returns the correct html_class' do
        expect(theme_config.html_class).to eq(html_class)
      end
    end

    context 'when the theme is light' do
      let(:theme) { env_light }

      it_behaves_like 'a valid theme',
                      color: '#4f46e5',
                      static: true,
                      html_class: 'light'
    end

    context 'when the theme is dark' do
      let(:theme) { env_dark }

      it_behaves_like 'a valid theme',
                      color: '#312e81',
                      static: true,
                      html_class: 'dark'
    end

    context 'when the theme is nil' do
      let(:theme) { {} }

      it_behaves_like 'a valid theme',
                      color: '#4f46e5',
                      static: false,
                      html_class: nil
    end

    context 'when the theme is invalid' do
      let(:theme) { { 'UI_THEME' => 'invalid_theme' } }

      it 'raises an error' do
        expect { theme_config }.to raise_error(ThemeConfig::Error)
      end
    end

    # Without UI_THEME the visitor decides, and the cookie carries the choice
    # to the server, so the first response already has the right theme.
    describe 'the choice of the visitor' do
      let(:theme) { {} }

      it 'follows a visitor who picked dark' do
        expect(theme_config.html_class('dark')).to eq('dark')
        expect(theme_config.color('dark')).to eq(described_class::DARK_COLOR)
        expect(theme_config.auto?('dark')).to be(false)
      end

      it 'follows a visitor who picked light' do
        expect(theme_config.html_class('light')).to eq('light')
        expect(theme_config.color('light')).to eq(described_class::LIGHT_COLOR)
        expect(theme_config.auto?('light')).to be(false)
      end

      it 'leaves the theme to the browser when nothing was picked' do
        expect(theme_config.auto?(nil)).to be(true)
        expect(theme_config.html_class(nil)).to be_nil
        expect(theme_config.color(nil)).to eq(described_class::LIGHT_COLOR)
      end

      it 'treats a value that is not a theme as no choice' do
        expect(theme_config.auto?('bogus')).to be(true)
        expect(theme_config.html_class('bogus')).to be_nil
      end
    end

    context 'when UI_THEME fixes the theme for everyone' do
      let(:theme) { env_dark }

      it 'ignores the choice of the visitor' do
        expect(theme_config.html_class('light')).to eq('dark')
        expect(theme_config.color('light')).to eq(described_class::DARK_COLOR)
        expect(theme_config.auto?('light')).to be(false)
      end
    end
  end

  # The browser learns the frame color twice: from the theme-color meta tag,
  # which Rails renders before any stylesheet loads, and from --color-chrome,
  # which paints the body. The two must agree, or the browser toolbar shows a
  # color the page never uses.
  describe 'the colors of the stylesheet' do
    let(:stylesheet) do
      Rails.root.join('app', 'frontend', 'entrypoints', 'application.css').read
    end

    def chrome_color(scope)
      stylesheet[/#{scope}\s*\{.*?--color-chrome:\s*(#\h{6})/m, 1]
    end

    it 'uses the light color for the default theme' do
      expect(chrome_color('@theme')).to eq(described_class::LIGHT_COLOR)
    end

    it 'uses the dark color for the dark theme' do
      expect(chrome_color('\.dark')).to eq(described_class::DARK_COLOR)
    end
  end

  # The offline page has no build step and no server, so it carries the two
  # colors by hand. This is the third copy, and the only one Rails never
  # renders. Without this spec it drifts and nobody sees it, because the page
  # only shows up when the app is unreachable.
  describe 'the colors of the offline page' do
    let(:page) { Rails.public_path.join('offline.html').read }

    # The light values come first in the file, the dark ones inside the
    # prefers-color-scheme block, so the first match is light and the second
    # one is dark.
    def colors(pattern)
      page.scan(pattern).flatten
    end

    it 'uses both colors for the theme-color meta tags' do
      expect(colors(/<meta\s+name="theme-color".*?content="(#\h{6})"/m)).to eq(
        [described_class::LIGHT_COLOR, described_class::DARK_COLOR],
      )
    end

    it 'uses both colors for the chrome of the page' do
      expect(colors(/--chrome:\s*(#\h{6})/)).to eq(
        [described_class::LIGHT_COLOR, described_class::DARK_COLOR],
      )
    end
  end
end
