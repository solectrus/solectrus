# HELIOS asks the user to come over through an amber dot: at its own menu
# item, at the button that opens the menu on desktop, and at the tab More of
# a phone.
describe 'HELIOS menu item' do
  before do
    allow(HeliosCheck).to receive_messages(
      available?: true,
      action_required?: action_required,
    )
    get '/power_balance/now'
  end

  let(:html) { response.parsed_body }
  let(:amber_dot) { 'span[aria-hidden="true"].bg-attention-strong' }
  # A button of the navigation sits on the color of the chrome, so its dot is light
  let(:button_dot) { 'span[aria-hidden="true"].bg-amber-400' }

  def helios_links
    html.css('a[href="http://www.example.com/helios"]')
  end

  def menu_buttons
    [
      html.at_css('button[data-action="click->slide-over--component#open"]'),
      html.at_css('nav[aria-label="Main navigation"] a[href="/more"]'),
    ]
  end

  context 'when HELIOS requires action' do
    let(:action_required) { true }

    it 'marks the menu item' do
      expect(helios_links).to be_present
      expect(helios_links).to all(satisfy { it.at_css(amber_dot) })
    end

    it 'marks the buttons that open the menu' do
      expect(menu_buttons).to all(satisfy { it.at_css(button_dot) })
    end
  end

  context 'when HELIOS requires nothing' do
    let(:action_required) { false }

    it 'leaves the menu item plain' do
      expect(helios_links).to be_present
      expect(helios_links.css(amber_dot)).to be_empty
    end

    it 'leaves the buttons plain' do
      expect(menu_buttons).to all(be_present)
      expect(menu_buttons).to all(satisfy { it.at_css(button_dot).nil? })
    end

    it 'opens HELIOS in a new tab' do
      expect(helios_links).to all(satisfy { it['target'] == '_blank' })
    end
  end
end
