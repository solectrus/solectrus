# A click on the menu item of HELIOS asks HELIOS first, because only the
# browser knows whether it reaches HELIOS.
describe 'HELIOS' do
  before do
    driven_by :playwright_mobile
    allow(HeliosCheck).to receive_messages(available?: true, action_required?: false)
    allow(HeliosCheck).to receive(:browser_url) { browser_url.call(it) }
    visit '/more'
  end

  context 'when the browser reaches HELIOS' do
    # The application answers on /up like HELIOS
    let(:browser_url) { ->(request) { request.base_url } }

    it 'opens HELIOS in a new tab' do
      helios = window_opened_by { click_on 'Konfiguration mit HELIOS' }

      expect(helios).to be_present
    end
  end

  # The browser can block the request although the link works
  context 'when the browser does not reach HELIOS' do
    let(:browser_url) { ->(_request) { 'http://127.0.0.1:1' } }

    before { click_on 'Konfiguration mit HELIOS' }

    it 'says so and stays on the page' do
      within('dialog#confirm-dialog') do
        expect(page).to have_text('HELIOS ist nicht erreichbar')
        click_on 'Abbrechen'
      end

      expect(page).to have_no_css('dialog#confirm-dialog[open]')
      expect(windows.size).to eq(1)
    end

    it 'tries HELIOS anyway' do
      helios = window_opened_by do
        within('dialog#confirm-dialog') { click_on 'Trotzdem versuchen' }
      end

      expect(helios).to be_present
    end
  end
end
