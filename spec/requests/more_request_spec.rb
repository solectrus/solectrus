# The page More of a phone lists the secondary items, which do not fit into
# the tab bar, and the items of the menu. A view among the secondary items
# stays a view: no title bar, and the timeframe of the other views. Each
# other page is a page below the page More, which leads back with a title bar.
describe 'Page More' do
  let(:html) { response.parsed_body }

  def more_tab
    html.at_css('nav[aria-label="Main navigation"] a[href="/more"]')
  end

  def tab(label)
    html.at_css(%(nav[aria-label="Main navigation"] a[aria-label="#{label}"]))
  end

  def group(header)
    html.css('main section').find { it.at_css('h2')&.text == header }
  end

  def group_links(header)
    group(header).css('a').index_by { it.text.strip }
  end

  def title_bar
    html.at_css('.ui-title-bar')
  end

  describe 'the list' do
    before { get '/more' }

    it 'names the brand with a logo in its title bar' do
      expect(title_bar.at_css('h1 img.ui-title-bar-logo')['alt']).to eq('More')
    end

    it 'marks the tab More' do
      expect(more_tab['aria-current']).to eq('page')
    end

    it 'lists the items beyond the tab bar in one group, the views first' do
      expect(group_links('Other views').keys).to eq(['Generation', 'Forecast', 'Essentials', 'Top 10', 'Amortization'])
    end

    it 'opens a view as it is, and slides into the other pages' do
      links = group_links('Other views')

      aggregate_failures do
        expect(links.values_at('Generation', 'Forecast').pluck('data-nav-title')).to all(be_nil)
        expect(links.values_at('Essentials', 'Top 10', 'Amortization').pluck('data-nav-title')).to eq(['Essentials', 'Top 10', 'Amortization'])
        expect(links['Amortization']['data-nav-plain']).to eq('true')
        expect(links['Top 10']['data-nav-plain']).to be_nil
      end
    end

    it 'leaves out the charging sessions, a page below the car page' do
      expect(html.at_css('main a[href^="/cars/charging_sessions"]')).to be_nil
    end

    it 'offers the language, the theme and the colors' do
      appearance = group('Appearance')

      aggregate_failures do
        expect(appearance.css('form[action="/locale"] button').map { it.text.strip }).to eq(%w[DE EN])
        expect(appearance.at_css('input[name="theme"]')).to be_present
        expect(appearance.at_css('input[name="colorPalette"]')).to be_present
      end
    end

    it 'switches the language with Turbo, which morphs the page in place' do
      form = group('Appearance').at_css('form[action="/locale"]')

      expect(form['data-turbo']).to be_nil
    end

    it 'offers a guest the login, not in red' do
      link = html.at_css('main a[href="/login"]')

      expect(link.at_css('.text-signal-negative')).to be_nil
    end
  end

  context 'without a sponsorship' do
    before do
      allow(PremiumStatus).to receive(:reason).and_return(nil)
      get '/more'
    end

    it 'shows the state of the sponsorship above the lists' do
      first = html.at_css('main .flex-col > *')

      expect(first.at_css('a[href="/sponsoring"]')).to be_present
    end

    it 'says at the theme and the colors that they are for sponsors' do
      hints = group('Appearance').css('a[href="/sponsoring"]').map { it.text.strip }

      expect(hints).to eq(['Only for sponsors'] * 2)
    end
  end

  context 'with a sponsorship' do
    before do
      allow(PremiumStatus).to receive(:reason).and_return(:sponsoring)
      get '/more'
    end

    it 'offers the theme and the colors without a hint' do
      expect(group('Appearance').at_css('a[href="/sponsoring"]')).to be_nil
    end
  end

  context 'when logged in as admin' do
    before do
      login_as_admin
      get '/more'
    end

    it 'slides into the settings' do
      expect(group_links('System')['Settings']['data-nav-title']).to eq('Settings')
    end

    it 'offers the logout in red' do
      expect(html.at_css('main a[href^="/logout"] .text-signal-negative')).to be_present
    end
  end

  describe 'the timeframe of the views' do
    it 'goes from the last view to the views in the list' do
      get '/house/house_power/2026-06'
      get '/more'

      aggregate_failures do
        expect(group_links('Other views')['Generation']['href']).to eq('/inverter/inverter_power/2026-06')
        expect(tab('House consumption')['href']).to eq('/house/house_power/2026-06')
      end
    end

    it 'goes to the power balance, which picks its sensor itself' do
      get '/house/house_power/2026-06'
      get '/more'

      expect(tab('Power balance')['href']).to eq('/?timeframe=2026-06')
    end

    it 'leaves the links without a timeframe before any view' do
      get '/more'

      expect(group_links('Other views')['Generation']['href']).to eq('/inverter/inverter_power')
    end
  end

  describe 'a view in the list' do
    before { get '/inverter/inverter_power/now' }

    it 'shows no title bar' do
      expect(title_bar).to be_nil
    end

    it 'marks the tab More' do
      expect(more_tab['aria-current']).to eq('page')
    end
  end

  describe 'a page below the page More' do
    before { get '/top10/day/inverter_power/sum/desc' }

    it 'leads back with a title bar that names it' do
      back = title_bar.at_css('a.ui-title-bar-back')

      aggregate_failures do
        expect(title_bar.at_css('h1').text.strip).to eq('Top 10')
        expect(back['href']).to eq('/more')
        expect(back['data-nav-logo']).to be_present
      end
    end

    it 'stands on the gray of a grouped list on a phone' do
      aggregate_failures do
        expect(title_bar['class']).not_to include('ui-title-bar-plain')
        expect(html.at_css('#inner')['class']).to include('max-lg:bg-gray-100')
      end
    end

    it 'leaves out its own icon, as the title bar names it' do
      expect(html.at_css('.ui-title-bar-accessory .fa-trophy')).to be_nil
    end

    it 'marks the tab More' do
      expect(more_tab['aria-current']).to eq('page')
    end
  end

  describe 'a view in the tab bar' do
    before { get '/house/house_power/now' }

    it 'shows no title bar and marks only itself' do
      aggregate_failures do
        expect(title_bar).to be_nil
        expect(tab('House consumption')['aria-current']).to eq('page')
        expect(more_tab['aria-current']).to be_nil
      end
    end
  end

  describe 'the charging sessions' do
    before do
      login_as_admin
      get '/cars/charging_sessions'
      follow_redirect! while response.redirect?
    end

    it 'mark the tab of the car, not the tab More' do
      aggregate_failures do
        expect(tab('Electric vehicle')['aria-current']).to eq('page')
        expect(more_tab['aria-current']).to be_nil
      end
    end
  end

  describe 'the settings' do
    before do
      login_as_admin
      get '/settings'
    end

    it 'lead back to the list, with its logo for the slide' do
      back = title_bar.at_css('a.ui-title-bar-back')

      aggregate_failures do
        expect(back['href']).to eq('/more')
        expect(back['data-nav-logo']).to be_present
        expect(more_tab['aria-current']).to eq('page')
      end
    end
  end

  context 'with few tabs' do
    before do
      allow(Setting).to receive_messages(enable_custom_consumer: false, enable_heatpump: false, enable_multi_inverter: false)
      allow(Sensor::HomePage).to receive(:available?).and_call_original
      allow(Sensor::HomePage).to receive(:available?).with(:cars).and_return(false)
    end

    it 'shows another page of the tab bar without a title bar' do
      get '/essentials'

      aggregate_failures do
        expect(tab('Essentials')['aria-current']).to eq('page')
        expect(title_bar).to be_nil
      end
    end
  end
end
