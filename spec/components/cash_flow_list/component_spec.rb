describe CashFlowList::Component, type: :component do
  subject(:component) { described_class.new(cash_flows: CashFlow.ordered) }

  # The rows take the address of the list from its controller (see ListAddress)
  around { |example| with_controller_class(Settings::CashFlowsController) { example.run } }

  context 'without entries' do
    before { render_inline(component) }

    it 'introduces the cash flows' do
      expect(page).to have_text('No cash flows yet. Add investments')
    end
  end

  context 'without entries for the filter' do
    before { render_inline(described_class.new(cash_flows: CashFlow.ordered, filter_categories: %w[repair])) }

    it 'says that nothing matches' do
      expect(page).to have_text('No cash flows match this filter.')
    end
  end

  context 'with entries' do
    let!(:cash_flow) do
      CashFlow.create!(date: Date.new(2021, 3, 1), amount: -5000, category: 'investment', note: 'Panels')
    end

    before do
      CashFlow.create!(date: Date.new(2021, 5, 1), amount: 800, category: 'subsidy', note: 'Grant')

      render_inline(component)
    end

    it 'renders a row that opens the form of the cash flow' do
      row = page.find("a[href='/settings/cash_flows/#{cash_flow.id}/edit?return_to=%2Fsettings%2Fcash_flows']").ancestor('[data-controller="ui--table-row--component"]')

      aggregate_failures do
        expect(row).to have_css('a[data-nav-title]')
        expect(row.text).to include('Panels', '2021-03-01 · Investment')
      end
    end

    it 'renders the total' do
      expect(page).to have_text(/Total\S*4,200\.00/)
    end
  end
end
