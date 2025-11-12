describe 'Home page auto-refresh' do
  include ActiveSupport::Testing::TimeHelpers

  context 'when "now" view' do
    it 'refreshes and shows updated data after 5 seconds' do
      visit '/inverter_power/now'

      expect(page.title).to include('Live')
      expect(page).to have_content('12:00 Uhr')
      expect(page).to have_content('10,0 kW')

      add_influx_point(
        name: measurement_inverter_power_1,
        fields: {
          field_inverter_power_1 => 777,
        },
      )

      add_influx_point(
        name: measurement_inverter_power_2,
        fields: {
          field_inverter_power_2 => 666,
        },
      )

      travel_js(5.seconds)

      expect(page).to have_content('1,4 kW')
    end
  end
end
