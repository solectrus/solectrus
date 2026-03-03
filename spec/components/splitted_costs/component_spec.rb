describe SplittedCosts::Component, type: :component do
  subject(:component) do
    described_class.new(costs:, power_grid_ratio:, grid_costs:, pv_costs:)
  end

  let(:costs) { 12.34 }
  let(:power_grid_ratio) { 50 }
  let(:grid_costs) { nil }
  let(:pv_costs) { nil }

  it 'renders' do
    render_inline(component)

    expect(page).to have_text '50%'
    expect(page).to have_text '12€'
  end

  describe '#costs' do
    context 'without breakdown' do
      it 'returns original costs' do
        expect(component.costs).to eq(12.34)
      end
    end

    context 'with breakdown' do
      # Simulates rounding issue: 0.154 + 0.014 = 0.168
      # Without fix: displayed as 0.15 + 0.01 = 0.16, but total shows 0.17
      # With fix: total = 0.15 + 0.01 = 0.16
      let(:grid_costs) { 0.154 }
      let(:pv_costs) { 0.014 }
      let(:costs) { 0.168 }

      it 'calculates total from rounded parts' do
        expect(component.costs).to eq(0.16)
      end
    end
  end
end
