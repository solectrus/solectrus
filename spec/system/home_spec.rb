describe 'Home', type: :system, js: true, vcr: true do
  it 'shows values' do
    visit '/'

    click_on I18n.t('calculator.current')
    expect(page).to have_css('#tab-current')

    click_on I18n.t('calculator.day')
    expect(page).to have_css('#tab-day')

    click_on I18n.t('calculator.week')
    expect(page).to have_css('#tab-week')

    click_on I18n.t('calculator.month')
    expect(page).to have_css('#tab-month')

    click_on I18n.t('calculator.year')
    expect(page).to have_css('#tab-year')

    click_on I18n.t('calculator.all')
    expect(page).to have_css('#tab-all')
  end
end
