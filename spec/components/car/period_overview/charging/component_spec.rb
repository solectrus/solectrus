describe Car::PeriodOverview::Charging::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:, all: true)) }

  def sums(count: 0, **) = ChargingSession::Sums.empty.with(count:, rows: count, **)

  def card = html.at_css(%(section[aria-label="Charging"]))

  # The forms of the label of each source, an icon as its name
  def source_labels = card.css(%([data-car--share-bar--component-target="segment"])).map { |source| source.css('> span').map { [it.at_css('svg')&.[]('data-icon'), it.text.squish].compact.join(' ').strip } }

  # The tooltip of the cost
  def cost_tooltip = card.at_css('[data-stats-with-chart--component-sensor-name-param="car_charging_costs"] [data-tooltip-target="html"]').text.squish

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

  it 'leads with the charged energy, and below it the cost and the link to the sessions' do
    expect(card.text.squish).to start_with('2,078 kWhcharged')
    expect(card.at_css('a[href*="/charging_sessions/"]').text.squish).to eq('Charging sessions')
  end

  # A source shows what fits (see car/share_bar/component_controller.ts),
  # its share stands in its tooltip
  it 'shows each source as wide as its energy, with its icon and its energy or its icon alone' do
    expect(source_labels).to eq([['sun 1,157 kWh', 'sun'], ['bolt 767 kWh', 'bolt'], ['charging-station 154 kWh', 'charging-station']])
    expect(card.css(%([data-car--share-bar--component-target="segment"])).map { it.parent['style'] }).to eq(['flex: 1157.0 1 0%', 'flex: 767.0 1 0%', 'flex: 154.0 1 0%'])
  end

  it 'names the energy, the share and the cost of each source in its own tooltip' do
    tooltips = card.css(%([data-car--share-bar--component-target="segment"])).map { it.parent.at_css('[data-tooltip-target="html"]').text.squish }

    expect(tooltips).to eq(
[
      'PhotovoltaicsCharged energy1,157 kWhShare56 %Lost feed-in revenue98 €',
      'GridCharged energy767 kWhShare37 %Grid import costs214 €',
      'Offsite chargingCharged energy154 kWhShare7 %Price paid60 €',
    ],
)
  end

  # The cost of each source as a sum, and the cost below them
  it 'adds up the cost of each source in the tooltip of the cost' do
    expect(cost_tooltip).to start_with('Energy cost of chargingPhotovoltaics98 €Grid+ 214 €Offsite charging+ 60 €Total= 372 €')
  end

  # A phone shows the charged energy as the only number of the card
  it 'names the energy and the share of each source and the cost in the tooltip of the charged energy' do
    tooltip = card.at_css('> a[data-stats-with-chart--component-sensor-name-param="car_charging"] [data-tooltip-target="html"]').text.squish

    expect(tooltip).to eq('ChargingPhotovoltaics1,157 kWh56 %Grid767 kWh37 %Offsite charging154 kWh7 %Energy cost372 €')
  end

  # The phone row holds the link alone, the row of a wider screen also the
  # cost. A phone shows the icon of a source alone.
  it 'shows the link alone and the icons of the sources alone on a phone' do
    expect(card.css('> div.lg\:hidden > *').map { it.text.squish }).to eq(['Charging sessions'])
    expect(card.css('> div.max-lg\:hidden > *').map { it.text.squish }).to match([start_with('372 €Energy cost'), 'Charging sessions'])
    expect(card.css('[data-car--share-bar--component-target="segment"] > span:first-child > span.max-lg\:hidden').size).to eq(3)
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_charging car_charging_costs])
  end

  # A session without a price has no cost, so the sum is the least cost
  context 'with a session without a price' do
    let(:offsite) { sums(count: 7, kwh: 154.0, cost: 60.0, uncosted: 1) }

    it 'marks the cost as a minimum and tells why' do
      energy_tooltip = card.at_css('> a[data-stats-with-chart--component-sensor-name-param="car_charging"] [data-tooltip-target="html"]').text.squish

      expect(card.text.squish).to include('≥ 372 €')
      expect([cost_tooltip, energy_tooltip]).to all(include(I18n.t('charging_sessions.cost_incomplete')))
    end
  end

  context 'without charging' do
    let(:wallbox) { sums }
    let(:offsite) { sums }

    it 'says so alone' do
      expect(card.text.squish).to eq('No charging sessions')
    end

    it 'loads no chart and links no list' do
      expect(charts).to be_empty
      expect(html.css('a[href*="/charging_sessions/"]')).to be_empty
    end

    # The link names the sessions that the numbers leave out
    context 'with sessions without a car' do
      before { allow(report).to receive(:unassigned_sessions).and_return(sums(count: 2)) }

      it 'keeps the figures and the link, with the text in the place of the bar' do
        expect(card.text.squish).to include('0 kWhcharged', 'No charging sessions', 'Charging sessions')
      end
    end
  end

  # Without the power splitter, the wallbox has no PV and grid
  context 'without the power splitter' do
    before { allow(report).to receive(:split?).and_return(false) }

    it 'shows the wallbox and the offsite sessions' do
      expect(source_labels).to eq([['plug 1,924 kWh', 'plug'], ['charging-station 154 kWh', 'charging-station']])
    end
  end

  # "all" leaves out the sessions without a car, so the link to the list
  # names them
  context 'with sessions without a car' do
    before { allow(report).to receive(:unassigned_sessions).and_return(sums(count: 2)) }

    it 'names them at the link to the wallbox sessions' do
      link = html.at_css('div.max-lg\:hidden > a[href*="/charging_sessions/"]')

      expect(link['href']).to include('/charging_sessions/wallbox/2025')
      expect(link.text).to include(I18n.t('car_breakdown.unassigned', count: 2))
    end

    # A phone opens the list in a sheet over the car page (see SheetPage)
    it 'opens the list in a sheet on a phone' do
      link = html.at_css('div.lg\:hidden > a[href*="/charging_sessions/"]')

      expect(link['href']).to include('/charging_sessions/wallbox/2025?sheet=1')
      expect(link['data-turbo-frame']).to eq('modal')
    end
  end
end
