describe TrendOverview::Component, type: :component do
  subject(:page) { render_inline(described_class.new(overview:)) }

  let(:overview) do
    instance_double(TrendOverview::Changes, groups:, page: :balance, timeframe: Timeframe.new('2025'), link_params: { base: nil })
  end

  let(:groups) { { grid_battery: [grid_import, row(:grid_export_power, percent: 10.0)], quotas: [autarky], averages: [outdoor_temp] } }
  let(:grid_import) { row(:grid_import_power, percent: 59.5) }
  let(:autarky) { row(:autarky, diff: -16.9) }
  let(:outdoor_temp) { row(:outdoor_temp, diff: 0.54) }

  def row(name, percent: nil, diff: nil, comparable: true)
    trend = instance_double(Trend, current_value: 1, comparable?: comparable, percent:, diff:)
    TrendOverview::Changes::Row.new(sensor: Sensor::Registry[name], trend:)
  end

  def row_of(name) = page.css('.trend-overview-row').find { it.css('.trend-overview-name').text == name }

  it 'groups the rows' do
    expect(page.css('.trend-overview-header').map(&:text)).to eq(['Grid & battery'])
  end

  it 'joins groups of one row each in a row into one without a heading' do
    merged = page.css('section').last

    expect(page.css('section').size).to eq(2)
    expect(merged.at_css('.trend-overview-header')).to be_nil
    expect(merged.css('.trend-overview-row').size).to eq(2)
  end

  it 'leads to the insights of its sensor' do
    link = row_of('Grid import')

    expect(link[:href]).to eq('/insights/grid_import_power/2025')
    expect(link['data-nav-title']).to eq(Sensor::Registry[:grid_import_power].display_name)
  end

  it 'runs a change beyond the scale to its edge, with a break' do
    bar = row_of('Grid import').at_css('.trend-overview-bar')

    expect(bar[:class]).to include('is-up', 'bg-signal-negative')
    expect(bar[:style]).to eq('width: 50.0%')
    expect(bar.at_css('.trend-overview-break')).to be_present
    expect(row_of('Grid import').at_css('.trend-overview-value').text).to eq('+60 %')
  end

  it 'shows a change of a percentage in points' do
    autarky_row = row_of('Autarky')
    bar = autarky_row.at_css('.trend-overview-bar')

    expect(bar[:class]).to include('is-down', 'bg-signal-negative')
    expect(bar[:style]).to eq('width: 16.9%')
    expect(bar.at_css('.trend-overview-break')).to be_nil
    expect(autarky_row.at_css('.trend-overview-value').text).to eq('-17 pp')
  end

  it 'shows the difference of an average without a bar' do
    temp_row = row_of(Sensor::Registry[:outdoor_temp].display_name)

    expect(temp_row.at_css('.trend-overview-track.is-empty')).to be_present
    expect(temp_row.at_css('.trend-overview-bar')).to be_nil
    expect(temp_row.at_css('.trend-overview-value').text).to eq('+0.5 °C')
  end

  context 'with a single group' do
    let(:groups) { { consumption: [row(:total_consumption, percent: 5.0), row(:house_power, percent: 3.0), row(:wallbox_power, percent: 1.0)] } }

    it 'needs no heading' do
      expect(page.css('.trend-overview-header')).to be_empty
    end

    # The total consumption sums up the house and the wallbox
    it 'sets the total apart from the rows it sums up' do
      lists = page.css('ul.trend-overview-group')

      expect(lists.map { it.css('.trend-overview-row').size }).to eq([1, 2])
      expect(lists.first.text).to include(Sensor::Registry[:total_consumption].display_name)
    end
  end

  context 'with a neutral sensor' do
    let(:groups) { { heat: [row(:heatpump_heating_power, percent: 20.0)] } }

    it 'shows its change in gray' do
      expect(page.at_css('.trend-overview-bar')[:class]).to include('bg-slate-400/70')
      expect(page.at_css('.trend-overview-value')[:class]).not_to include('text-signal')
    end
  end

  context 'with a change that rounds to zero' do
    let(:groups) { { generation: [row(:inverter_power, percent: 0.3)] } }

    it 'shows a dot in place of a bar' do
      expect(page.css('.trend-overview-dot')).to be_present
      expect(page.css('.trend-overview-bar')).to be_empty
      expect(page.at_css('.trend-overview-value').text).to eq('±0 %')
    end
  end

  context 'with a difference that rounds to zero' do
    let(:groups) { { averages: [row(:outdoor_temp, diff: 0.02)] } }

    it 'shows the zero with its unit' do
      expect(page.at_css('.trend-overview-value').text).to eq('±0 °C')
    end
  end

  context 'without a value of the earlier period' do
    let(:groups) { { generation: [row(:inverter_power, comparable: false)] } }

    it 'shows a dash' do
      expect(page.css('.trend-overview-bar, .trend-overview-dot')).to be_empty
      expect(page.at_css('.trend-overview-value').text).to eq('–')
    end
  end

  context 'without a row' do
    let(:groups) { {} }

    it 'tells that there is no data' do
      expect(page.text).to include('No data available!')
      expect(page.css('section')).to be_empty
    end
  end
end
