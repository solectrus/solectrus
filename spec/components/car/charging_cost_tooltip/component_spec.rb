describe Car::ChargingCostTooltip::Component, type: :component do
  subject(:html) { render_inline(described_class.new(balance:)) }

  let(:charge_split) { instance_double(Car::ChargeSplit, split?: true, cost: { pv: 2.323, grid: 3.504, offsite: 0.0 }) }
  let(:balance) do
    instance_double(Car::Balance, charge_split:, charging_costs: 5.827, charging_costs_complete?: true)
  end
  let(:session_totals) do
    {
      wallbox: { count: 2, wh: 20_000, cost: 5.827 },
      offsite: { count: 1, wh: 0, cost: 0.0 },
      guest: { count: 0, wh: 0, cost: nil },
    }
  end

  before do
    stub_feature(:power_splitter)
    allow(balance).to receive(:session_totals) { session_totals[it] }
  end

  def amounts = html.css('td.text-right').map { it.text.squish }

  context 'with the power splitter' do
    it 'rounds the parts to add up to the total' do
      expect(amounts).to eq(['2.32 €', '3.51 €', '0 €', '5.83 €'])
    end
  end

  context 'without the power splitter' do
    let(:charge_split) { instance_double(Car::ChargeSplit, split?: false, cost: nil) }
    let(:session_totals) do
      {
        wallbox: { count: 2, wh: 20_000, cost: 2.323 },
        offsite: { count: 1, wh: 5_000, cost: 3.504 },
        guest: { count: 0, wh: 0, cost: nil },
      }
    end

    it 'rounds the wallbox and the offsite part to add up to the total' do
      expect(amounts).to eq(['2.32 €', '3.51 €', '5.83 €'])
    end
  end
end
