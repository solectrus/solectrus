describe Car::ChargingCard::Component, type: :component do
  subject(:html) do
    render_inline(described_class.new(balance:, timeframe: Timeframe.new('2025')))
  end

  let(:cars) { [Car.new(id: 1)] }
  let(:charge_split) do
    instance_double(Car::ChargeSplit, energy: energy_parts, cost: { pv: 98.0, grid: 214.0, offsite: 60.0 })
  end
  let(:balance) do
    instance_double(
      Car::Balance,
      charged_wh: 2_078_000,
      charging_costs: 372.0,
      car_max_range: 304,
      car: (cars.sole if cars.one?),
      charge_split:,
    )
  end
  let(:energy_parts) { { pv: 1_157_000, grid: 767_000, offsite: 154_000 } }
  let(:session_totals) do
    {
      wallbox: { count: 12, wh: 1_924_000, cost: 312.0 },
      offsite: { count: 7, wh: 154_000, cost: 60.0 },
      guest: { count: 2, wh: 21_000, cost: 6.5 },
    }
  end

  before do
    stub_feature(:power_splitter)
    allow(Car::ChargingCostTooltip::Component).to receive(:new).and_return(nil)
    allow(balance).to receive(:session_totals) { session_totals[it] }
  end

  it 'shows the charged energy' do
    expect(html.text.squish).to include('2,078')
  end

  it 'gives each segment a tooltip with its share and its cost' do
    tooltips = html.css('.segment [data-tooltip-target="html"]').map { it.text.squish }

    expect(tooltips).to contain_exactly(
      a_string_including(I18n.t('car_breakdown.offsite'), '7 %', '60'),
      a_string_including(I18n.t('car_breakdown.home_grid'), '37 %', '214'),
      a_string_including(I18n.t('car_breakdown.home_pv'), '56 %', '98'),
    )
  end

  it 'stacks a segment for each source, offsite on top and PV at the bottom' do
    heights = html.css('.segment').pluck('style')

    expect(heights).to eq(['height: 7.4%', 'height: 36.9%', 'height: 55.7%'])
  end

  context 'without offsite energy' do
    let(:energy_parts) { { pv: 1_157_000, grid: 767_000, offsite: 0 } }

    it 'leaves out its segment' do
      expect(html.css('.segment').size).to eq(2)
    end
  end

  it 'gives the energy of each source' do
    expect(html.text.squish).to include(
      I18n.t('car_breakdown.home_pv'),
      '1,157',
      I18n.t('car_breakdown.home_grid'),
      '767',
      I18n.t('car_breakdown.offsite'),
      '154',
    )
  end

  it 'shows the charging cost, the maximum range and the sessions' do
    expect(html.text.squish).to include(
      I18n.t('sensors.car_charging_costs'),
      '372',
      '304',
      I18n.t('car_breakdown.wallbox_short'),
      '12',
      I18n.t('car_breakdown.offsite_short'),
      '7',
    )
  end

  it 'links the wallbox and the offsite badge to the sessions of the car' do
    expect(html.css('a').pluck('href')).to include(
      a_string_including('/charging_sessions/wallbox', 'car=1'),
      a_string_including('/charging_sessions/offsite', 'car=1'),
    )
  end

  it 'links the guest badge to the guest sessions, as an outline' do
    badge = html.css('a').find { it['href'].include?('car=guest') }

    expect(badge['href']).to include('/charging_sessions/wallbox')
    expect(badge['class']).to include('ring-1')
  end

  it 'gives each badge a tooltip with its energy and its cost' do
    badges = html.css('a[href*="/charging_sessions/"]')
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

  context 'with costs that round apart' do
    let(:charge_split) do
      instance_double(Car::ChargeSplit, energy: energy_parts, cost: { pv: 2.323, grid: 3.504, offsite: 0.0 })
    end

    it 'rounds the costs of the segments to add up to the charging cost' do
      tooltips = html.css('.segment [data-tooltip-target="html"]').map { it.text.squish }

      expect(tooltips).to contain_exactly(
        a_string_including(I18n.t('car_breakdown.offsite'), '0 €'),
        a_string_including(I18n.t('car_breakdown.home_grid'), '3.51'),
        a_string_including(I18n.t('car_breakdown.home_pv'), '2.32'),
      )
    end
  end

  context 'with the selection "all" of several cars' do
    let(:cars) { [Car.new(id: 1), Car.new(id: 2)] }

    it 'shows no maximum range, because the cars have batteries of their own' do
      expect(html.text.squish).not_to include('304')
    end
  end

  context 'without the power splitter' do
    let(:energy_parts) { nil }

    it 'shows the charged energy in one segment' do
      expect(html.css('.segment').pluck('style')).to eq(['height: 100%'])
    end
  end

  context 'without charged energy' do
    let(:balance) do
      instance_double(
        Car::Balance,
        charged_wh: 0,
        charging_costs: nil,
        car_max_range: 335,
        car: (cars.sole if cars.one?),
        charge_split:,
      )
    end
    let(:energy_parts) { { pv: 0, grid: 0, offsite: 0 } }
    let(:session_totals) { %i[wallbox offsite guest].index_with { { count: 0, wh: 0, cost: nil } } }

    it 'shows no segment' do
      expect(html.css('.segment')).to be_empty
    end
  end
end
