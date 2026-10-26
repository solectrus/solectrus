describe Car::ChargingBox::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:, all: true)) }

  def sums(count: 0, **) = ChargingSession::Sums.empty.with(count:, rows: count, **)

  # The value and the caption of a phone of each figure
  def tiles = html.css('section > div.grid > *').map { |tile| tile.css('> span').first(2).map { it.text.squish } }

  # The caption of the desktop of each figure with one of its own
  def wide_labels = html.css('section > div.grid > * > span.max-lg\:hidden').map { it.text.squish }

  # The parts of the bar of the sources, in the order of the bar
  def bar = html.css('section > div.grid span[style*="flex-grow"]').map { it['style'][/var\(--color-[\w-]+\)/] }

  # The colors of the swatch before the title
  def swatch = html.xpath('.//h2/preceding-sibling::span/span').map { it['style'][/var\(--color-[\w-]+\)/] }

  # The charts that a click on a figure loads
  def charts = html.css('[data-stats-with-chart--component-sensor-name-param]').pluck('data-stats-with-chart--component-sensor-name-param').uniq

  let(:wallbox) { sums(count: 12, kwh: 1924.0, kwh_grid: 767.0, cost: 312.0, cost_grid: 214.0) }
  let(:offsite) { sums(count: 7, kwh: 154.0, cost: 60.0) }
  let(:report) do
    instance_double(
      Car::Report,
      timeframe: Timeframe.new('2025'),
      split?: true,
      guest_sessions: sums,
      proposal_count: 0,
      unassigned_sessions: sums,
    )
  end

  before do
    stub_feature(:power_splitter)
    allow(report).to receive(:sessions) { |kind = nil, **| { wallbox:, offsite:, nil => ChargingSession::Sums.sum([wallbox, offsite]) }[kind] }
    allow(report).to receive(:sources) { Car::Report.sources_of(wallbox, offsite, split: report.split?) }
  end

  # Like a bar of a charge in the timeline of a day. The share of PV has no
  # bar of its own.
  it 'shows the sources in the swatch before the title' do
    expect(bar).to be_empty
    expect(swatch).to eq(%w[var(--color-car-pv) var(--color-car-grid) var(--color-car-offsite)])
  end

  it 'shows the charged energy, the share of PV and the cost' do
    expect(tiles).to eq(
      [
        ['2,078 kWh', 'charged'],
        ['56 %', 'from PV'],
        ['372 €', 'cost'],
      ],
    )
  end

  it 'names the cost in full on the desktop' do
    expect(wide_labels).to eq([I18n.t('sensors.car_charging_costs')])
  end

  it 'loads the chart of the energy and of the cost' do
    expect(charts).to eq(%w[car_charging car_charging_costs])
  end

  # A session without a price has no cost, so the sum is the least cost
  context 'with a session without a price' do
    let(:offsite) { sums(count: 7, kwh: 154.0, cost: 60.0, uncosted: 1) }

    it 'marks the cost as a minimum and tells why' do
      expect(tiles.last.first).to eq('≥ 372 €')
      expect(html.text).to include(I18n.t('charging_sessions.cost_incomplete'))
    end
  end

  # A period without charging keeps its tiles, which load no chart
  context 'without charging' do
    let(:wallbox) { sums }
    let(:offsite) { sums }

    it 'shows 0 and dashes in the same tiles' do
      expect(tiles).to eq(
        [
          ['0 kWh', 'charged'],
          ['–', 'from PV'],
          ['–', 'cost'],
        ],
      )
    end

    it 'has no bar of the sources' do
      expect(bar).to be_empty
      expect(swatch).to eq(%w[var(--color-fill-strong)])
    end

    it 'loads the empty charts, but links no list' do
      expect(charts).to eq(%w[car_charging car_charging_costs])
      expect(html.css('a[href*="/charging_sessions/"]')).to be_empty
    end
  end

  # Without the power splitter, the share is the one of the wallbox, which
  # says something only next to offsite sessions
  context 'without the power splitter' do
    before { allow(report).to receive(:split?).and_return(false) }

    it 'shows the share of the wallbox' do
      expect(tiles[1]).to eq(['93 %', I18n.t('car_breakdown.share_wallbox')])
    end

    context 'with the wallbox alone' do
      let(:offsite) { sums }

      it 'has no share' do
        expect(tiles.size).to eq(2)
        expect(bar).to be_empty
      end
    end
  end

  # "all" leaves out the sessions without a car, so the link to the list
  # names them
  context 'with sessions without a car' do
    before { allow(report).to receive(:unassigned_sessions).and_return(sums(count: 2)) }

    it 'names them at the link to the wallbox sessions' do
      link = html.at_css('a.max-lg\:hidden[href*="/charging_sessions/"]')

      expect(link['href']).to include('/charging_sessions/wallbox/2025')
      expect(link.text).to include(I18n.t('car_breakdown.unassigned', count: 2))
    end

    # A phone opens the list in a sheet over the car page (see SheetPage)
    it 'opens the list in a sheet on a phone' do
      link = html.at_css('a.lg\:hidden[href*="/charging_sessions/"]')

      expect(link['href']).to include('/charging_sessions/wallbox/2025?sheet=1')
      expect(link['data-turbo-frame']).to eq('modal')
    end
  end
end
