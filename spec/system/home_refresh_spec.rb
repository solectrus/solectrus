describe 'Home page auto-refresh' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

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

  context 'when "day" view' do
    it 'automatically switches to next day when current day ends' do
      visit '/inverter_power/2022-06-21'

      expect(page).to have_content('Dienstag, 21. Juni 2022')

      # Fast forward to next day (12 hours + 5 minutes)
      travel_js(12.hours + 5.minutes)

      # Should automatically switch to next day
      expect(page).to have_content('Mittwoch, 22. Juni 2022')
      expect(page).to have_current_path('/inverter_power/2022-06-22')
    end
  end

  context 'when "week" view' do
    it 'automatically switches to next week when current week ends' do
      visit '/inverter_power/2022-W25'

      expect(page).to have_content('KW 25, 2022')

      # Fast forward to next week (5 days + 12 hours + 5 minutes)
      travel_js(5.days + 12.hours + 5.minutes)

      # Should automatically switch to next week
      expect(page).to have_content('KW 26, 2022')
      expect(page).to have_current_path('/inverter_power/2022-W26')
    end
  end

  context 'when "month" view' do
    it 'automatically switches to next month when current month ends' do
      visit '/inverter_power/2022-06'

      expect(page).to have_content('Juni 2022')

      # Fast forward to next month (9 days + 12 hours + 5 minutes)
      travel_js(9.days + 12.hours + 5.minutes)

      # Should automatically switch to next month
      expect(page).to have_content('Juli 2022')
      expect(page).to have_current_path('/inverter_power/2022-07')
    end
  end
end
