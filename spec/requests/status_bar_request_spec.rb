# The value of this tag is load bearing, and only one of them is wrong. A
# translucent status bar makes iOS 26 and later paint a band of frosted glass
# over the top of an installed web app, which blurs the row the app puts there.
# Every other value keeps the band away, and light-content is the one that also
# asks for the white status bar text the dark app frame needs.
describe 'Status bar of the installed app' do
  # Slim sorts attributes alphabetically, so match the tag as a whole and pick
  # the content out of it instead of relying on their order.
  def status_bar_style
    tag =
      response
        .body
        .scan(/<meta[^>]*>/)
        .find { it.include?('"apple-mobile-web-app-status-bar-style"') }

    tag[/content="([^"]*)"/, 1]
  end

  # The root redirects, so ask for the page it redirects to.
  it 'asks for a status bar that carries no glass' do
    get '/power_balance/now'

    expect(status_bar_style).to eq('light-content')
  end
end
