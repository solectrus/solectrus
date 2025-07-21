describe 'Top 10' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

  %w[
    inverter_power
    house_power
    grid_import_power
    grid_export_power
    battery_discharging_power
    battery_charging_power
    wallbox_power
    heatpump_power
  ].each do |sensor|
    describe "#{sensor} sensor" do
      it 'loads top10 pages and allows navigation' do
        # Start with day view
        visit "/top10/day/#{sensor}/sum/desc"
        expect(page.status_code).to eq(200)
        expect(page).to have_content('TAG')

        # Wait for turbo frame to load with chart content
        expect(page).to have_css('#chart-day')
        expect(page).to have_content('1.')

        # Navigate to week
        first('a', text: 'WOCHE').click
        expect(page).to have_current_path("/top10/week/#{sensor}/sum/desc")
        expect(page).to have_css('#chart-week')

        # Navigate to month
        first('a', text: 'MONAT').click
        expect(page).to have_current_path("/top10/month/#{sensor}/sum/desc")
        expect(page).to have_css('#chart-month')

        # Navigate to year
        first('a', text: 'JAHR').click
        expect(page).to have_current_path("/top10/year/#{sensor}/sum/desc")
        expect(page).to have_css('#chart-year')
      end

      it 'allows sorting functionality' do
        visit "/top10/year/#{sensor}/sum/desc"
        # Accept various energy units depending on sensor and values
        expect(page).to have_content(/[kMGT]?Wh/)

        find('a[aria-label="Sortierung wechseln"]').click
        expect(page).to have_current_path("/top10/year/#{sensor}/sum/asc")

        find('a[aria-label="Sortierung wechseln"]').click
        expect(page).to have_current_path("/top10/year/#{sensor}/sum/desc")
      end

      it 'displays chart elements correctly' do
        visit "/top10/day/#{sensor}/sum/desc"
        # Accept both Wh and kWh units depending on value size
        expect(page).to have_content(/[kMGT]?Wh/)

        # Verify chart table exists
        expect(page).to have_css('#chart-day')

        # Verify chart contains data rows
        within '#chart-day' do
          expect(page).to have_css('.table-row', minimum: 1)
        end

        # Verify ranking numbers are present (1., 2., etc.)
        expect(page).to have_content('1.')

        # Verify the chart shows dates and energy values
        expect(page).to have_content(/\d{4}/) # Year pattern
        expect(page).to have_content('Aufsummierte Energie')
      end
    end
  end
end
