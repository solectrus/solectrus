describe 'Balance page (economics)' do
  it_behaves_like(
    'balance navigation',
    %w[
      autarky
      self_consumption_quote
      grid_costs
      savings
      grid_revenue
    ],
  )
end
