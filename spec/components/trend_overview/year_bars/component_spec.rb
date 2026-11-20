describe TrendOverview::YearBars::Component, type: :component do
  subject(:page) { render_inline(described_class.new(row:)) }

  let(:row) { TrendOverview::Years::Row.new(sensor: Sensor::Registry[sensor_name], values:, partial_years: [2026]) }
  let(:sensor_name) { :inverter_power }
  let(:values) { { 2023 => nil, 2024 => 5_000.0, 2025 => 10_000.0, 2026 => 2_500.0 } }

  def years = page.css('.trend-overview-years > span')
  def bars = page.css('.trend-overview-year')

  # The lines of the tooltip of a year
  def tooltip(index)
    years[index].at_css('[data-tooltip-target="html"]').inner_html.split('<br>').map { Nokogiri::HTML.fragment(it).text.squish }
  end

  it 'keeps the place of a year without a value' do
    expect(years.size).to eq(4)
    expect(years.first.children).to be_empty
  end

  it 'scales a sum from zero' do
    expect(bars.pluck(:style)).to eq(['height: 50.0%', 'height: 100.0%', 'height: 25.0%'])
  end

  it 'marks the best year and pales the partial one' do
    expect(bars[1][:class]).to include('bg-signal-positive')
    expect(bars[2][:class]).to include('is-partial')
    expect(bars[2][:class]).not_to include('bg-signal-positive')
  end

  it 'names the year and its value in the tooltip' do
    expect(tooltip(1)).to eq(['2024', '5.0 kWh'])
    expect(tooltip(2)).to eq(['2025', '10.0 kWh', 'Best year'])
    expect(tooltip(3)).to eq(['2026', '2.5 kWh', 'Partial year'])
  end

  context 'with a temperature' do
    let(:sensor_name) { :outdoor_temp }
    let(:values) { { 2024 => 10.0, 2025 => 12.0, 2026 => 11.0 } }

    it 'starts below the lowest year' do
      expect(bars.pluck(:style)).to eq(['height: 20.0%', 'height: 100.0%', 'height: 60.0%'])
    end
  end
end
