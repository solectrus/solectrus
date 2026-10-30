describe CashFlow::List::Component, type: :component do
  subject(:component) { described_class.new(cash_flows: CashFlow.ordered) }

  # The rows take the address of the list from its controller (see ListAddress)
  around { |example| with_controller_class(Settings::CashFlowsController) { example.run } }

  context 'without entries' do
    before { render_inline(component) }

    it 'introduces the cash flows' do
      expect(page).to have_text('No cash flows yet')
      expect(page).to have_text('Add investments')
    end
  end

  context 'without entries for the filter' do
    before { render_inline(described_class.new(cash_flows: CashFlow.ordered, filter: CashFlow::Filter.new(categories: %w[repair]))) }

    it 'says that nothing matches' do
      expect(page).to have_text('No cash flows match this filter')
    end
  end

  context 'with entries' do
    let!(:cash_flow) do
      CashFlow.create!(date: Date.new(2021, 3, 1), amount: -5000, category: 'investment', note: 'Panels')
    end

    before do
      CashFlow.create!(date: Date.new(2022, 5, 1), amount: 800, category: 'subsidy', note: 'Grant')

      render_inline(component)
    end

    it 'renders a row that opens the form of the cash flow' do
      row = page.find("a[href='/settings/cash_flows/#{cash_flow.id}/edit?return_to=%2Fsettings%2Fcash_flows']").ancestor('[data-controller="ui--table-row--component"]')

      aggregate_failures do
        expect(row['data-ui--table-row--component-form-sheet-value']).to eq('true')
        expect(row.text).to include('Panels', '2021-03-01 · Investment')
      end
    end

    it 'names the year above its cash flows, with a link that narrows the list to it' do
      headers = page.all('h3.ui-group-header')

      expect(headers.map(&:text)).to eq(%w[2022 2021])
      expect(headers.last).to have_link(href: '/settings/cash_flows?from=2021-01-01&to=2021-12-31')
    end

    it 'needs no header of a year in the list of a single year' do
      render_inline(described_class.new(cash_flows: CashFlow.ordered, filter: CashFlow::Filter.new.with_year(Date.new(2021))))

      expect(page).to have_no_css('h3.ui-group-header')
    end

    it 'renders the total' do
      expect(page).to have_text(/Total\S*4,200\.00/)
    end
  end
end
