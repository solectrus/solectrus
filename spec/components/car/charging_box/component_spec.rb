describe Car::ChargingBox::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:, all: true)) }

  def sums(count: 0, **) = ChargingSession::Sums.empty.with(count:, rows: count, **)

  # The row of the figures above the bar
  def row = html.at_css('section > div.rounded-xl > div:first-child')

  # The lead, without a caption
  def lead = row.at_css('> :first-child > span').text.squish

  # The value and the caption of a phone of each figure beside the lead
  def tiles = row.css('> div > *').map { |tile| tile.css('> span').first(2).map { it.text.squish } }

  # The forms of the label of each part of the bar, in the order of the bar,
  # an icon as its name
  def bar_labels = html.css('[data-car--share-bar--component-target="segment"]').map { |part| part.css('> span').map { [it.at_css('svg')&.[]('data-icon'), it.text.squish].compact.join(' ').strip } }

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

  it 'leads with the charged energy, beside it the energy cost' do
    expect(lead).to eq('2,078 kWh')
    expect(tiles).to eq([['372 €', 'Energy cost']])
  end

  # Like a bar of a charge in the timeline of a day. Only PV has its share.
  it 'shows the sources in a bar, the share of PV in it' do
    expect(bar_labels).to eq([['sun 56 %', '56 %', 'sun'], ['bolt'], ['charging-station']])
  end

  it 'names the energy and the share of each source in the tooltip of the bar' do
    tooltip = html.at_css('section > div.rounded-xl > a [data-tooltip-target="html"]').text.squish

    expect(tooltip).to include('Photovoltaics1,157 kWh56 %', 'Grid767 kWh37 %', 'Offsite charging154 kWh7 %')
  end

  it 'loads the chart of the energy and of the cost' do
    expect(charts).to eq(%w[car_charging car_charging_costs])
  end

  # A session without a price has no cost, so the sum is the least cost
  context 'with a session without a price' do
    let(:offsite) { sums(count: 7, kwh: 154.0, cost: 60.0, uncosted: 1) }

    it 'marks the cost as a minimum and tells why' do
      expect(tiles.first.first).to eq('≥ 372 €')
      expect(html.text).to include(I18n.t('charging_sessions.cost_incomplete'))
    end
  end

  # A period without charging says so in the place of the figures, which
  # would be 0 and dashes
  context 'without charging' do
    let(:wallbox) { sums }
    let(:offsite) { sums }

    it 'says so instead of the figures' do
      expect(html.css('section a')).to be_empty
      expect(html.css('section > div').last.text.squish).to eq('No charging sessions')
    end

    # The bar keeps its place, so the box has the height of one with charging
    it 'keeps the place of the bar' do
      expect(html.at_css('.invisible [data-controller="car--share-bar--component"]')).to be_present
    end

    it 'loads no chart and links no list' do
      expect(charts).to be_empty
      expect(html.css('a[href*="/charging_sessions/"]')).to be_empty
    end

    # The numbers leave them out, so the figures stay with 0 beside the link
    # that names them
    context 'with sessions without a car' do
      before { allow(report).to receive(:unassigned_sessions).and_return(sums(count: 2)) }

      it 'keeps the figures' do
        expect(lead).to eq('0 kWh')
        expect(html.text).not_to include('No charging sessions')
      end
    end
  end

  # Without the power splitter, the share is the one of the wallbox, which
  # says something only next to offsite sessions
  context 'without the power splitter' do
    before { allow(report).to receive(:split?).and_return(false) }

    it 'shows the share of the wallbox' do
      expect(bar_labels.first).to eq(['plug 93 %', '93 %', 'plug'])
    end

    context 'with the wallbox alone' do
      let(:offsite) { sums }

      it 'has no share' do
        expect(bar_labels).to eq([['plug']])
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
