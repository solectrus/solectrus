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

  # Safari reads the color from a fixed element at the top edge before it
  # falls back to the body, and it takes that color as it is instead of
  # lightening it.
  def theme_strip_tag
    response.body[/<div[^>]*id="theme-strip"[^>]*>/]
  end

  def theme_strip
    theme_strip_tag[/style="(position: fixed[^"]*)"/, 1]
  end

  # The script that applies the theme of the operating system. nil when the
  # server knows the theme and renders the class itself.
  def system_theme_script
    response.body[%r{<script src="(/system-theme\.js[^"]*)"}, 1]
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

  describe 'the strip Safari reads its toolbar color from' do
    before { get page }

    # Every one of these has to be inline. Safari reads the page before the
    # stylesheet arrives, and a strip styled by a class has no size or color
    # at that moment.
    it 'carries its size and color without the stylesheet' do
      expect(theme_strip).to include(
        'position: fixed',
        'top: 0',
        chrome_style(ThemeConfig::LIGHT_COLOR),
      )
    end

    # It stands behind the navigation and stops where that ends, because the
    # content starts there. A taller strip covers the top of the page, and
    # lifting the content over it with a z-index breaks the fullscreen chart.
    it 'is as high as the navigation' do
      expect(theme_strip).to include('height: 4rem')
    end

    # A page without a sub navigation starts its content at the top edge. Below
    # lg no navigation stands above that content, so the stylesheet drops the
    # height to zero there and the strip cannot cover it.
    it 'gives way where the content starts at the top edge' do
      get '/essentials'

      expect(theme_strip).to include('height: var(--theme-strip-height, 4rem)')
    end

    it 'sits behind the navigation and takes no clicks' do
      expect(theme_strip).to include('z-index: 1', 'pointer-events: none')
    end

    # The whole point: a Turbo visit replaces the body, and Safari reads the
    # color again in that moment. This element is what it finds.
    it 'survives a Turbo visit' do
      expect(theme_strip_tag).to include('data-turbo-permanent')
    end

    # The strip lies behind the navigation. Give the navigation a background
    # again and it hides the strip, and Safari reads the body instead, which
    # it lightens. The header behind both still carries the color.
    it 'is not hidden by the navigation' do
      nav = response.body[/<nav[^>]*class="([^"]*)"/, 1]

      expect(nav).to be_present
      expect(nav).not_to match(/\bbg-/)
    end

    # The strip and the html element carry inline styles, because the
    # stylesheet is not there yet when Safari reads the color. Drop
    # unsafe-inline from style-src and the browser refuses those styles, and
    # the toolbar color goes back to being wrong.
    it 'is allowed by the content security policy' do
      style_src = response.headers['Content-Security-Policy'][/style-src[^;]*/]

      expect(style_src).to include("'unsafe-inline'")
    end
  end

  context 'when the visitor picked dark' do
    before { get page, headers: { 'Cookie' => 'theme=dark' } }

    # Nothing is left for the browser to decide, so no script goes out.
    it 'sends no script for the system theme' do
      expect(system_theme_script).to be_nil
    end

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

    # The theme hangs on the dark class, and the server cannot name it here.
    # The script sets it while the head is parsed, before anything paints.
    # Without it the page paints light on a dark system and the theme selector
    # corrects it once its modules have loaded.
    it 'applies the theme of the system before the first paint' do
      expect(system_theme_script).to start_with('/system-theme.js?v=')
      expect(Rails.public_path.join('system-theme.js')).to exist
    end

    # A module or a deferred script would run after the paint, which is the
    # flash this prevents. The tag has to stay a plain, blocking one.
    it 'does not defer the script' do
      tag = response.body[%r{<script src="/system-theme\.js[^>]*>}]

      expect(tag).not_to include('defer', 'async', 'module')
    end

    # No nonce and no hash needed, so the policy can stay as it is.
    it 'is allowed by the content security policy without an exception' do
      script_src =
        response.headers['Content-Security-Policy'][/script-src[^;]*/]

      expect(script_src).to include("'self'")
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
