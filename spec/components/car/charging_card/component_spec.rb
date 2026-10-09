describe Car::ChargingCard::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  def sums(count: 0, **) = ChargingSession::Sums.empty.with(count:, rows: count, **)

  # A badge is a block with a link over its whole area
  def badges(html = self.html) = html.css('a.inset-0[aria-label]').map(&:parent)

  def badge(path, html = self.html) = badges(html).find { it.at_css('a.inset-0')['href'].include?(path) }

  def ring(html = self.html) = html.at_css('.donut-chart [style*="conic-gradient"]')

  def ring_colors(html = self.html) = ring(html)['style'].scan(/var\((--color-sensor-[a-z-]+)\)/).flatten

  def center(html = self.html) = html.css('.donut-chart .inset-1\/4 .text-center > div').map { it.text.squish }.join(' ').presence

  def tooltip(html = self.html) = html.at_css('.donut-chart [data-tooltip-target="html"]')

  def tooltip_rows(html = self.html) = tooltip(html).css('tr').map { it.text.squish }.compact_blank

  # The energy of each source in the tooltip of the charged energy
  def energies(html = self.html) = html.css('.label-value-row').map { "#{it.at_css('.flex span').text.squish} #{it.xpath('span').text.squish}" }

  let(:car) { Car.new(id: 1) }
  let(:wallbox) { sums(count: 12, kwh: 1924.0, kwh_grid: 767.0, cost: 312.0, cost_grid: 214.0) }
  let(:offsite) { sums(count: 7, kwh: 154.0, cost: 60.0) }
  let(:guest) { sums(count: 2, kwh: 21.0, cost: 6.5) }
  let(:report) do
    instance_double(
      Car::Report,
      timeframe: Timeframe.new('2025'),
      split?: true,
      cars: [car],
      car:,
      guest_sessions: guest,
      proposal_count: 0,
      unassigned_sessions: sums,
    )
  end

  before do
    stub_feature(:power_splitter)
    allow(report).to receive(:sessions) { |kind = nil| { wallbox:, offsite:, nil => ChargingSession::Sums.sum([wallbox, offsite]) }[kind] }
    allow(report).to receive(:sources) { Car::Report.sources_of(wallbox, offsite, split: report.split?) }
  end

  it 'shows the charged energy' do
    expect(html.text.squish).to include('2,078')
  end

  it 'draws a part of the ring for each source, PV first' do
    expect(ring_colors).to eq(%w[--color-sensor-pv --color-sensor-grid --color-sensor-offsite])
  end

  it 'shows the share of PV in the center of the ring' do
    expect(center).to eq("56 % #{I18n.t('car_breakdown.share_pv')}")
  end

  it 'gives the energy of each source in the tooltip of the charged energy' do
    expect(energies).to eq(
      [
        "#{I18n.t('car_breakdown.home_pv')} 1,157 kWh",
        "#{I18n.t('car_breakdown.home_grid')} 767 kWh",
        "#{I18n.t('car_breakdown.offsite')} 154 kWh",
      ],
    )
  end

  it 'gives the share and the cost of each source and the charging cost in the tooltip of the ring' do
    expect(tooltip_rows).to match(
      [
        a_string_including(I18n.t('car_breakdown.home_pv'), '56 %', '98'),
        a_string_including(I18n.t('car_breakdown.home_grid'), '37 %', '214'),
        a_string_including(I18n.t('car_breakdown.offsite'), '7 %', '60'),
        a_string_including(I18n.t('sensors.car_charging_costs'), '372'),
        a_string_including(I18n.t('car_breakdown.guest_additional'), '6.5'),
      ],
    )
  end

  it 'loads the chart of the charged energy from the ring' do
    charts = html.css('.donut-chart a').pluck('data-stats-with-chart--component-sensor-name-param')

    expect(charts.uniq).to eq(['car_charging'])
  end

  it 'shows no cost in red' do
    expect(html.css('.text-signal-negative')).to be_empty
  end

  context 'without offsite energy' do
    let(:offsite) { ChargingSession::Sums.empty }

    it 'leaves out its part' do
      expect(ring_colors).to eq(%w[--color-sensor-pv --color-sensor-grid])
      expect(energies.size).to eq(2)
    end
  end

  it 'shows the sessions' do
    expect(html.text.squish).to include(
      I18n.t('car_breakdown.wallbox_short'),
      '12',
      I18n.t('car_breakdown.offsite_short'),
      '7',
    )
  end

  it 'links the wallbox and the offsite badge to the sessions of the car' do
    expect(html.css('a').pluck('href')).to include(
      a_string_including('/cars/1/charging_sessions/wallbox'),
      a_string_including('/cars/1/charging_sessions/offsite'),
    )
  end

  it 'links the guest badge to the guest sessions, in the color of the others' do
    badge = badge('/cars/guest/charging_sessions/wallbox')

    expect(badge).to be_present
    expect(badge['class']).to include('bg-slate-200')
  end

  it 'gives each badge a tooltip with its energy and its cost' do
    tooltips = badges.map { it.at_css('[data-tooltip-target="html"]').text.squish }

    expect(badges.pluck('title').compact).to be_empty
    expect(tooltips).to match(
      [
        a_string_including(I18n.t('car_breakdown.wallbox_sessions'), '1,924', '312'),
        a_string_including(I18n.t('car_breakdown.offsite_sessions'), '154', '60'),
        a_string_including(I18n.t('car_breakdown.guest_sessions'), '21', '6.5'),
      ],
    )
  end

  it 'points to the unconfirmed offsite sessions, which the count leaves out' do
    allow(report).to receive(:proposal_count).and_return(3)
    badge = badge('/cars/1/charging_sessions/offsite')

    expect(badge.css('a[href*="/cars/proposals/charging_sessions/offsite"] svg[data-icon="circle-question"]')).to be_present
    expect(badge.at_css('[data-tooltip-target="html"]').text).to include('3 unconfirmed sessions')
  end

  it 'points to the wallbox sessions that are not assigned on "all"' do
    allow(report).to receive(:unassigned_sessions).and_return(sums(count: 6, kwh: 123.8))
    html = render_inline(described_class.new(report:, all: true))
    badge = badge('/cars/1/charging_sessions/wallbox', html)

    expect(badge.css('a[href*="/cars/unassigned/charging_sessions/wallbox"] svg[data-icon="circle-question"]')).to be_present
    expect(badge.at_css('[data-tooltip-target="html"]').text.squish).to include('6 sessions not assigned', '123.8')
  end

  it 'shows no icon without unconfirmed sessions' do
    expect(html.css('svg[data-icon="circle-question"]')).to be_empty
  end

  context 'with costs that round apart' do
    let(:wallbox) { sums(count: 12, kwh: 1924.0, kwh_grid: 767.0, cost: 5.827, cost_grid: 3.504) }
    let(:offsite) { sums(count: 7, kwh: 154.0, cost: 0.0) }

    it 'rounds the costs of the sources to add up to the charging cost' do
      expect(tooltip_rows.first(4)).to match(
        [
          a_string_including(I18n.t('car_breakdown.home_pv'), '2.32'),
          a_string_including(I18n.t('car_breakdown.home_grid'), '3.51'),
          a_string_including(I18n.t('car_breakdown.offsite'), '0 €'),
          a_string_including(I18n.t('sensors.car_charging_costs'), '5.83'),
        ],
      )
    end
  end

  context 'without the power splitter' do
    before { allow(report).to receive(:split?).and_return(false) }

    it 'draws the wallbox and the offsite sessions' do
      expect(ring_colors).to eq(%w[--color-sensor-wallbox --color-sensor-offsite])
    end

    it 'shows the share of the wallbox in the center of the ring' do
      expect(center).to eq("93 % #{I18n.t('car_breakdown.share_wallbox')}")
    end

    context 'without offsite energy' do
      let(:offsite) { ChargingSession::Sums.empty }

      it 'shows nothing in the center of the ring' do
        expect(ring_colors).to eq(%w[--color-sensor-wallbox])
        expect(center).to be_blank
      end
    end
  end

  # A day draws the curve of the wallbox, so without a wallbox the charged
  # energy has no chart there. The offsite sessions still count.
  context 'with a day without a wallbox' do
    before do
      allow(report).to receive(:timeframe).and_return(Timeframe.new('2025-06-15'))
      Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_WALLBOX_POWER', 'INFLUX_SENSOR_WALLBOX_CAR_CONNECTED'))
    end

    def charts = html.css('a').filter_map { it['data-stats-with-chart--component-sensor-name-param'] }

    it 'shows the charged energy and its ring without a link to a chart' do
      expect(html.text.squish).to include('2,078')
      expect(ring).to be_present
      expect(charts).not_to include('car_charging')
    end

    # A tap on a ring without a chart opens its tooltip
    it 'opens the tooltip of the ring with a tap' do
      expect(html.at_css('.donut-chart [data-controller="tooltip"]')['data-tooltip-touch-value']).to eq('true')
    end
  end

  # No day of the sessions has a price, so their sum of 0 is no cost
  context 'without a price' do
    let(:wallbox) { sums(count: 12, kwh: 1924.0, kwh_grid: 767.0, uncosted: 12) }
    let(:offsite) { sums(count: 7, kwh: 154.0, uncosted: 7) }
    let(:guest) { sums(count: 2, kwh: 21.0, uncosted: 2) }

    it 'gives the shares and names the missing price in the tooltip of the ring' do
      expect(tooltip_rows.size).to eq(3)
      expect(tooltip.text.squish).to include('56 %', I18n.t('car_breakdown.cost_missing'))
    end

    it 'shows no cost in the tooltips of the ring and the badges' do
      tooltips = [tooltip, *badges.map { it.at_css('[data-tooltip-target="html"]') }]

      expect(tooltips.size).to eq(4)
      expect(tooltips.map(&:text).join).not_to match(/[€$]/)
    end
  end

  context 'without charged energy' do
    let(:wallbox) { ChargingSession::Sums.empty }
    let(:offsite) { ChargingSession::Sums.empty }
    let(:guest) { ChargingSession::Sums.empty }

    it 'shows an empty ring that names the missing charge, without a tooltip' do
      expect(html.css('.donut-chart')).to be_present
      expect(center).to eq(I18n.t('car_breakdown.no_charging'))
      expect(ring).to be_nil
      expect(tooltip).to be_nil
      expect(energies).to be_empty
      expect(html.at_css('a[href*="car_charging"]')['data-controller']).to be_nil
    end
  end
end
