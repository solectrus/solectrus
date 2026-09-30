describe ConsumeDetails::Component, type: :component do
  subject(:component) { described_class.new(data:) }

  let(:timeframe) { Timeframe.new('2024-06') }

  # grid_costs is grid_energy_costs plus grid_base_fee. The breakdown reads the
  # two halves out of the same query, so it cannot drift from the sum above it.
  let(:values) do
    {
      %i[grid_import_power sum] => 2000.0,
      %i[grid_energy_costs sum] => grid_costs - base_fee,
      %i[grid_base_fee sum] => base_fee,
      %i[grid_costs sum] => grid_costs,
      %i[self_consumption sum] => 10_000.0,
      %i[opportunity_costs sum] => 30.0,
      %i[total_costs sum] => grid_costs + 30.0,
    }
  end

  # Wrapped the way the badge wraps it, so the component is exercised against
  # the object it really gets.
  let(:data) { PowerBalance.new(Sensor::Data::Single.new(values, timeframe:)) }

  let(:grid_costs) { 50.0 }

  before { render_inline(component) }

  def numbers
    page.all('.sensor-value-number').map(&:text)
  end

  context 'without a base fee' do
    let(:base_fee) { 0.0 }

    it 'renders no breakdown' do
      expect(page).to have_no_text('Base fee')
      expect(page).to have_no_text('Energy costs')
    end

    # Every row keeps the decimals its unit asks for: money hides the cents
    # above 10, and nothing has to line up.
    it 'renders the numbers as the data has them' do
      expect(page).to have_css(
        '.sensor-grid-costs .sensor-value-number',
        text: '50',
      )
      expect(page).to have_css(
        '.sensor-total-costs .sensor-value-number',
        text: '80',
      )
    end
  end

  context 'with a base fee' do
    let(:base_fee) { 15.0 }

    it 'splits the grid costs into energy costs and base fee' do
      expect(page).to have_css(
        '.sensor-grid-energy-costs .sensor-value-number',
        text: '35',
      )
      expect(page).to have_css(
        '.sensor-grid-base-fee .sensor-value-number',
        text: '15',
      )
    end

    # The sum and the total it feeds stay the numbers the query produced.
    it 'keeps the sums' do
      expect(page).to have_css(
        '.sensor-grid-costs .sensor-value-number',
        text: '50',
      )
      expect(page).to have_css(
        '.sensor-total-costs .sensor-value-number',
        text: '80',
      )
    end
  end

  # Money hides the cents above 10, so a column printing each row by its own
  # rule reads "8.22 + 2.29 = 11". The widest precision any row asks for is the
  # one they all share.
  context 'with amounts below and above ten' do
    let(:grid_costs) { 10.51 }
    let(:base_fee) { 2.29 }

    it 'prints every row with the cents the small ones need' do
      expect(numbers).to include('8.22', '2.29', '10.51')
    end
  end

  # A year of costs has no business showing cents, and does not need them: the
  # sums are built from the rows as printed.
  context 'with amounts money rounds to whole euros' do
    let(:grid_costs) { 4739.66 }
    let(:base_fee) { 821.76 }

    it 'prints no cents, and still adds up' do
      # 3918 + 822 = 4740, and 4740 + 30 = 4770
      expect(numbers).to include('3,918', '822', '4,740', '4,770')
      expect(numbers).not_to include('3,917.90', '821.76', '4,739.66')
    end
  end

  # Both sums also show outside the tooltip: grid_costs in the badge it hangs
  # on, total_costs on its own page. Rounding every row on its own reads
  # "0.63 + 0.57 = 1.20" below a badge saying 1.21, so the rows carry the
  # difference and the sums stay what the query produced.
  context 'with parts that round away from their sum' do
    let(:grid_costs) { 1.2065 }
    let(:base_fee) { 0.5726 }
    let(:values) do
      super().merge(
        %i[opportunity_costs sum] => 0.9667,
        %i[total_costs sum] => grid_costs + 0.9667,
      )
    end

    it 'prints rows that add up to the sums' do
      # 0.64 + 0.57 = 1.21, and 1.21 + 0.96 = 2.17
      expect(numbers).to eq(%w[0.64 2.0 0.57 1.21 0.96 10.0 2.17])
    end
  end

  # An install without a grid meter has neither half, and no breakdown.
  context 'without the halves' do
    let(:base_fee) { 0.0 }
    let(:values) do
      super().except(%i[grid_energy_costs sum], %i[grid_base_fee sum])
    end

    it 'renders no breakdown' do
      expect(page).to have_no_text('Base fee')
      expect(page).to have_css(
        '.sensor-grid-costs .sensor-value-number',
        text: '50',
      )
    end
  end

  # The key figure shows 4,83 EUR for the grid costs. Rounded on their own, the
  # rows would show 4,83 + 10 = 15.
  context 'with grid costs below ten' do
    let(:data) do
      Sensor::Data::Single.new(
        {
          grid_costs: 4.834,
          opportunity_costs: 10.204,
          total_costs: 15.038,
          grid_import_power: 16_000,
          self_consumption: 48_000,
        },
        timeframe: Timeframe.day,
      )
    end

    it 'keeps the grid costs of the key figure and adds up to the total' do
      expect(component.costs.parts).to eq([4.83, 10.21])
      expect(component.costs.sum).to eq(15.04)
    end

    it 'shows all amounts with the precision of the grid costs' do
      expect(page).to have_text('10.21')
      expect(page).to have_text('15.04')
    end
  end
end
