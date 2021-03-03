describe 'Top10', type: :system, js: true do
  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    (0..11).each do |index|
      add_influx_point name: 'SENEC', fields: { inverter_power: (index + 1) * 1000 }, time: (beginning + index.month).end_of_month
      add_influx_point name: 'SENEC', fields: { inverter_power: (index + 1) * 1000 }, time: (beginning + index.month).beginning_of_month
    end

    add_influx_point name: 'SENEC', fields: { inverter_power: 14_000 }
  end

  it 'presents data and allows navigation' do
    visit '/top10/day/inverter_power'
    expect(page).to have_text(I18n.t('layout.top10').upcase)

    navigate_day
    navigate_month
    navigate_year

    click_on I18n.t('senec.inverter_power')
    expect(page).to have_text(I18n.t('senec.house_power'))
    click_on I18n.t('senec.house_power')

    navigate_day
    navigate_month
    navigate_year
  end

  private

  def navigate_day
    click_on I18n.t('calculator.day')
    expect(page).to have_css('#chart-day', visible: :all)
  end

  def navigate_month
    click_on I18n.t('calculator.month')
    expect(page).to have_css('#chart-month', visible: :all)
  end

  def navigate_year
    click_on I18n.t('calculator.year')
    expect(page).to have_css('#chart-year', visible: :all)
  end
end
