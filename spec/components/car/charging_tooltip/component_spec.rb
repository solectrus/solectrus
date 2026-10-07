describe Car::ChargingTooltip::Component, type: :component do
  subject(:html) { render_inline(described_class.new(sources:, costs:, guest_cost: nil, complete: true)) }

  def source(key, whole_percent) = described_class::Source.new(key:, whole_percent:)

  def amounts = html.css('td.text-right').map { it.text.squish }

  context 'with the power splitter' do
    let(:sources) { [source(:pv, 40), source(:grid, 50), source(:offsite, 10)] }
    let(:costs) { described_class::Costs.of(pv: 2.323, grid: 3.504, offsite: 0.0) }

    it 'shows the share and the cost of PV, grid and offsite, rounded to add up to the total' do
      expect(amounts).to eq(['40 %', '2.32 €', '50 %', '3.51 €', '10 %', '0 €', '5.83 €'])
    end
  end

  context 'without the power splitter' do
    let(:sources) { [source(:wallbox, 60), source(:offsite, 40)] }
    let(:costs) { described_class::Costs.of(wallbox: 2.323, offsite: 3.504) }

    it 'shows the share and the cost of the wallbox and offsite, rounded to add up to the total' do
      expect(amounts).to eq(['60 %', '2.32 €', '40 %', '3.51 €', '5.83 €'])
    end
  end

  context 'without a cost' do
    let(:sources) { [source(:pv, 40), source(:grid, 60)] }
    let(:costs) { nil }

    it 'shows the shares and names the missing price' do
      expect(amounts).to eq(['40 %', '60 %'])
      expect(html.text).to include(I18n.t('car_breakdown.cost_missing'))
    end
  end
end
