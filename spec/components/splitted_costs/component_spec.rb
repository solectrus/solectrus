describe SplittedCosts::Component, type: :component do
  subject(:component) { described_class.new(costs:, power_grid_ratio:) }

  let(:costs) { 12.34 }
  let(:power_grid_ratio) { 50 }

  it 'renders' do
    render_inline(component)

    expect(page).to have_text '50 %'
    expect(page).to have_text '12 €'
  end
end
