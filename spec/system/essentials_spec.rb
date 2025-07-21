describe 'Essentials' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

  it 'displays tiles with values' do
    visit '/essentials'

    expect(page).to have_css('#tile-inverter_power-now')
    expect(page).to have_css('#tile-inverter_power-day')
    expect(page).to have_css('#tile-inverter_power-month')
    expect(page).to have_css('#tile-inverter_power-year')
    expect(page).to have_css('#tile-co2_reduction-year')
    expect(page).to have_css('#tile-savings-year')

    # Check for specific values (the exact values might vary based on test data)
    within '#tile-inverter_power-now' do
      expect(page).to have_content(/\d+([.,]\d+)?/)
    end

    within '#tile-co2_reduction-year' do
      expect(page).to have_content(/\d+/)
    end

    within '#tile-savings-year' do
      expect(page).to have_content(/\d+/)
    end
  end
end
