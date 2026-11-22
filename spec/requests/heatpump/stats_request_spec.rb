describe 'Heat pump stats' do
  before do
    travel_to Date.new(2026, 1, 20).in_time_zone.change(hour: 12)
    stub_feature(:heatpump)
    allow(Summary).to receive(:missing_or_stale_days_for).and_return([])

    create_summary(date: Date.new(2026, 1, 10), values: [[:outdoor_temp, :avg, 2.0], [:heatpump_heating_power, :sum, 30_000], [:heatpump_power, :sum, 10_000]])
    create_summary(date: Date.new(2026, 1, 11), values: [[:outdoor_temp, :avg, 14.0], [:heatpump_heating_power, :sum, 0], [:heatpump_power, :sum, 0]])
  end

  def outdoor_tile = Nokogiri::HTML5.fragment(response.body.gsub(%r{</?template>}, '')).css('a').find { it.text.include?('Outdoor') }

  def get_stats(timeframe) = get heatpump_stats_path(sensor_name: 'heatpump_heating_power', timeframe:), headers: { 'Turbo-Frame' => 'stats' }

  # The day without heat counts not at all
  it 'shows the outdoor temperature while heating beside the average' do
    get_stats('2026-01')

    expect(outdoor_tile.text.squish).to include('8.0 °C', '2.0 °C')
    heating = outdoor_tile.css('[data-controller="tooltip"]').last
    expect(heating.at_css('.sr-only').text).to eq('Outdoor temperature while heating')
    expect(heating.text.squish).to include('2.0 °C')
  end

  # A single day has no other days to weight
  it 'shows the average alone for a day' do
    get_stats('2026-01-10')

    expect(outdoor_tile.text).not_to include('while heating')
  end
end
