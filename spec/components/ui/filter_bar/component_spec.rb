describe Ui::FilterBar::Component, type: :component do
  let(:filter) { CashFlow::Filter.new(categories: %w[investment repair]) }
  let(:calendar) { "svg[data-icon='#{IconSet.find('calendar').name}']" }

  # The links take the path of the list from its controller (see FilteredList)
  around { |example| with_controller_class(Settings::CashFlowsController) { example.run } }

  before do
    render_inline(described_class.new(filter:, category_pill: CashFlow::CategoryPill::Component)) do |bar|
      bar.with_pill(icon: 'car', remove_path: '/other') { 'Model 3' }
    end
  end

  it 'shows a pill for each part, with an x that removes this part' do
    aggregate_failures do
      expect(page).to have_css('[role=img][aria-label="Filtered by"][title="Filtered by"]')
      expect(page).to have_text('Model 3')
      expect(page.all('a[aria-label="Remove from filter"]').pluck(:href)).to eq(
        ['/other', '/settings/cash_flows?category%5B%5D=repair', '/settings/cash_flows?category%5B%5D=investment'],
      )
      expect(page).to have_link('Clear filter', href: '/settings/cash_flows')
      expect(page).to have_no_css(calendar)
    end
  end

  context 'with a calendar year' do
    let(:filter) { CashFlow::Filter.new.with_year(Date.new(2025, 6, 1)) }

    it 'shows the year' do
      expect(page.find(calendar).ancestor('span')).to have_text(/\A2025\z/)
    end
  end

  context 'with another range' do
    let(:filter) { CashFlow::Filter.new(from: Date.new(2025, 4, 1), to: Date.new(2026, 3, 31)) }

    it 'shows both ends' do
      expect(page).to have_text('2025-04-01 – 2026-03-31')
    end
  end

  context 'with an open end' do
    let(:filter) { CashFlow::Filter.new(from: Date.new(2025, 4, 1)) }

    it 'shows the start' do
      expect(page).to have_text('From 2025-04-01')
    end
  end

  context 'without a filter' do
    let(:filter) { CashFlow::Filter.new }

    it 'shows nothing' do
      expect(page.native.inner_html).to be_blank
    end
  end
end
