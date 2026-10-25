describe 'Timeframe pager (mobile)' do
  before { driven_by :playwright_mobile }

  # The period of the pager opens the picker of its kind, and the way back
  # leads to the fields
  it 'opens the picker of the period' do
    visit '/inverter_power/2022-06-21'

    within('nav[aria-label="Zeitraum"]') { find('a[aria-haspopup="dialog"]').click }

    expect(page).to have_text('Tag wählen')
    expect(page).to have_css('button[data-date="2022-06-21"]')

    click_on 'Anderer Zeitraum'

    expect(page).to have_css('h1', text: 'Zeitraum wählen')
    expect(page).to have_css('button[data-value="P7D"]')
  end
end
