describe Ui::FilterLink::Component, type: :component do
  let(:filter) { CashFlow::Filter.new(categories: %w[repair]) }

  # The link takes the path of the list from its controller (see FilteredList)
  around { |example| with_controller_class(Settings::CashFlowsController) { example.run } }

  it 'links to the list with the narrowed filter' do
    render_inline(described_class.new(filter:, narrowed: filter.with_year(Date.new(2025, 6, 1)), label: 'Filter by this year'))

    expect(page).to have_link('Filter by this year', href: '/settings/cash_flows?category%5B%5D=repair&from=2025-01-01&to=2025-12-31')
  end

  it 'does not show a link that would not change the filter' do
    render_inline(described_class.new(filter:, narrowed: filter.with_category('repair'), label: 'Filter by this category'))

    expect(page).to have_no_link
  end
end
