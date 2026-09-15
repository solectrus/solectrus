# The browser must get the final theme with the first byte. If the server
# answered with the light theme while the visitor picked dark, the browser
# would correct it after parsing, and the toolbar color would flicker on
# every load.
describe 'Theme of the first response' do
  before do
    allow(ApplicationPolicy).to receive(:themes?).and_return(true)
    allow(ThemeConfig).to receive(:x).and_return(theme_config)
  end

  # No UI_THEME, so the visitor decides. Pinned here instead of read from the
  # global config, which carries whatever the environment or another spec set.
  let(:theme_config) { ThemeConfig.new({}) }

  # The root redirects, so ask for the page it redirects to.
  let(:page) { '/power_balance/now' }

  def html_class
    response.body[/<html[^>]*class="([^"]*)"/, 1]
  end

  # Painted before the stylesheet arrives, so the page does not start white.
  def html_style
    response.body[/<html[^>]*style="([^"]*)"/, 1]
  end

  def chrome_style(color)
    "background-color: var(--color-chrome, #{color})"
  end

  # Slim sorts attributes alphabetically, so match the tag as a whole and pick
  # the attributes out of it instead of relying on their order.
  def theme_color_tags
    response
      .body
      .scan(/<meta[^>]*>/)
      .select { it.include?('name="theme-color"') }
      .map do |tag|
        {
          media: tag[/media="([^"]*)"/, 1],
          content: tag[/content="([^"]*)"/, 1],
        }
      end
  end

  context 'when the visitor picked dark' do
    before { get page, headers: { 'Cookie' => 'theme=dark' } }

    it 'renders the dark theme right away' do
      expect(html_class).to eq('dark')
      expect(html_style).to eq(chrome_style(ThemeConfig::DARK_COLOR))
      expect(theme_color_tags).to eq(
        [{ media: nil, content: ThemeConfig::DARK_COLOR }],
      )
    end
  end

  context 'when the visitor picked light' do
    before { get page, headers: { 'Cookie' => 'theme=light' } }

    it 'renders the light theme right away' do
      expect(html_class).to eq('light')
      expect(html_style).to eq(chrome_style(ThemeConfig::LIGHT_COLOR))
      expect(theme_color_tags).to eq(
        [{ media: nil, content: ThemeConfig::LIGHT_COLOR }],
      )
    end
  end

  # The palette swaps the sensor colors. It rides on a cookie for the same
  # reason the theme does: without it the first paint shows the standard colors
  # and the page corrects itself once the selector connects.
  describe 'the color palette' do
    it 'renders the contrast palette right away' do
      get page, headers: { 'Cookie' => 'color_palette=contrast; theme=dark' }

      expect(html_class).to eq('dark palette-contrast')
    end

    it 'leaves the class out for the standard palette' do
      get page

      expect(html_class).to be_nil
    end

    it 'ignores a value that is not a palette' do
      get page, headers: { 'Cookie' => 'color_palette=bogus' }

      expect(html_class).to be_nil
    end

    # A sponsor feature, same gate as the theme selector that offers it.
    it 'ignores the palette when themes are off' do
      allow(ApplicationPolicy).to receive(:themes?).and_return(false)
      get page, headers: { 'Cookie' => 'color_palette=contrast' }

      expect(html_class).to be_nil
    end
  end

  context 'when the visitor follows the operating system' do
    before { get page }

    it 'leaves the class to the browser' do
      expect(html_class).to be_nil
    end

    # The page starts light without the class, so the fallback says light too.
    it 'paints the frame light until the stylesheet decides' do
      expect(html_style).to eq(chrome_style(ThemeConfig::LIGHT_COLOR))
    end

    # Only the browser knows the system setting, so both colors go out and it
    # picks one. The dark tag comes first, because a browser takes the first
    # tag whose media matches and the tag without media always matches.
    it 'offers both colors through a media query' do
      expect(theme_color_tags).to eq(
        [
          {
            media: '(prefers-color-scheme: dark)',
            content: ThemeConfig::DARK_COLOR,
          },
          { media: nil, content: ThemeConfig::LIGHT_COLOR },
        ],
      )
    end
  end

  context 'when UI_THEME fixes the theme for everyone' do
    let(:theme_config) { ThemeConfig.new('UI_THEME' => 'light') }

    before { get page, headers: { 'Cookie' => 'theme=dark' } }

    it 'ignores the cookie and sends one tag, not a media query' do
      expect(html_class).to eq('light')
      expect(theme_color_tags).to eq(
        [{ media: nil, content: ThemeConfig::LIGHT_COLOR }],
      )
    end
  end
end
