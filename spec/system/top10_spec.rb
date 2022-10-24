describe 'Top10', js: true do
  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    12.times do |index|
      add_influx_point name: 'SENEC',
                       fields: {
                         inverter_power: (index + 1) * 1000,
                         house_power: (index + 1) * 100,
                         grid_power_plus: (index + 1) * 200,
                         grid_power_minus: (index + 1) * 300,
                         bat_power_plus: (index + 1) * 400,
                         bat_power_minus: (index + 1) * 500,
                         wallbox_charge_power: (index + 1) * 600,
                       },
                       time: (beginning + index.month).end_of_month
      add_influx_point name: 'SENEC',
                       fields: {
                         inverter_power: (index + 1) * 1000,
                         house_power: (index + 1) * 100,
                         grid_power_plus: (index + 1) * 200,
                         grid_power_minus: (index + 1) * 300,
                         bat_power_plus: (index + 1) * 400,
                         bat_power_minus: (index + 1) * 500,
                         wallbox_charge_power: (index + 1) * 600,
                       },
                       time: (beginning + index.month).beginning_of_month
    end

    add_influx_point name: 'SENEC', fields: { inverter_power: 14_000 }
  end

  Senec::POWER_FIELDS.each do |field|
    it "presents data and allows navigation for #{field}" do
      visit "/top10/day/#{field}"
      expect(page).to have_css('#chart-day')
      expect(page).to have_text(I18n.t('layout.top10').upcase)

      navigate_year
      navigate_month
      navigate_day
    end
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
