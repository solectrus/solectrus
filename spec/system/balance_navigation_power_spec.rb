describe 'Balance page (power sensors)' do
  it_behaves_like(
    'balance navigation',
    %w[
      inverter_power
      inverter_power_1
      inverter_power_2
      house_power
      heatpump_power
      wallbox_power
    ],
  )

  it 'loads charts when clicking a segment' do
    stub_feature(
      :relative_timeframe,
      :power_splitter,
      :insights,
      :finance_charts,
      :car,
    )

    visit '/inverter_power/now'

    expect(page).to have_css('#balance-chart-now')
    expect(page).to have_css('#segment-inverter_power')

    find_by_id('segment-inverter_power').click

    expect(page).to have_current_path('/inverter_power/now')
    expect(page).to have_css(
      '#balance-chart-now[src*="/charts/inverter_power/now"]',
    )

    within('#balance-chart-now') do
      expect(page).to have_css(
        'select[name="sensor-selector"] option[selected][value*="/inverter_power/now"]',
        visible: :all,
      )
    end
  end
end
