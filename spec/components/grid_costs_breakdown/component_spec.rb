describe GridCostsBreakdown::Component, type: :component do
  subject(:component) { described_class.new(data:) }

  let(:timeframe) { Timeframe.new('2024-06') }
  let(:values) do
    {
      %i[grid_import_power sum] => 2000.0,
      %i[grid_energy_costs sum] => grid_costs - base_fee,
      %i[grid_base_fee sum] => base_fee,
      %i[grid_costs sum] => grid_costs,
    }
  end
  let(:data) { PowerBalance.new(Sensor::Data::Single.new(values, timeframe:)) }
  let(:grid_costs) { 50.0 }

  before { render_inline(component) }

  def numbers
    page.all('.sensor-value-number').map(&:text)
  end

  context 'with a base fee' do
    let(:base_fee) { 15.0 }

    it 'shows base fee, energy costs and their sum' do
      expect(page).to have_text('Base fee')
      expect(page).to have_text('Energy costs')
      expect(page).to have_text('Grid costs')
      expect(numbers).to eq(%w[15 35 50])
    end

    it 'marks all amounts as negative (red)' do
      expect(page).to have_css('.sensor-grid-base-fee.text-signal-negative')
      expect(page).to have_css('.sensor-grid-energy-costs.text-signal-negative')
      expect(page).to have_css('.sensor-grid-costs.text-signal-negative')
    end
  end

  # Rounding every row on its own reads "0.57 + 0.63 = 1.21"
  context 'with parts that round away from their sum' do
    let(:grid_costs) { 1.2065 }
    let(:base_fee) { 0.5726 }

    it 'prints rows that add up to the sum' do
      expect(numbers).to eq(%w[0.57 0.64 1.21])
    end
  end

  context 'without a base fee' do
    let(:base_fee) { 0.0 }

    it 'shows the grid costs alone' do
      expect(page).to have_no_text('Base fee')
      expect(numbers).to eq(%w[50])
    end
  end

  # An install without a grid meter has neither half
  context 'without the halves' do
    let(:base_fee) { 0.0 }
    let(:values) do
      super().except(%i[grid_energy_costs sum], %i[grid_base_fee sum])
    end

    it 'shows the grid costs alone' do
      expect(page).to have_no_text('Base fee')
      expect(numbers).to eq(%w[50])
    end
  end
end
