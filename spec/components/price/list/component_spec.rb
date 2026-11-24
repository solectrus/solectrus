describe Price::List::Component, type: :component do
  subject(:component) { described_class.new(prices:, name:) }

  let(:name) { 'feed_in' }
  let(:prices) { Price.list_for(name) }

  context 'when there is a price of zero' do
    before do
      Price.create!(name:, starts_at: 2.days.ago, amount_per_kwh: 0)
      Price.create!(name:, starts_at: 1.day.ago, amount_per_kwh: 0.08)

      render_inline(component)
    end

    it 'renders component' do
      expect(page).to have_css '.grid'
    end
  end

  context 'when all prices are non-zero' do
    let!(:price) do
      Price.create!(name:, starts_at: 1.day.ago, amount_per_kwh: 0.08, note: 'New tariff')
    end

    before do
      Price.create!(name:, starts_at: 2.days.ago, amount_per_kwh: 0.06)

      render_inline(component)
    end

    it 'renders component with calculated change' do
      expect(page).to have_css '.grid', text: '&plus; 33 %'
    end

    it 'renders a row that opens the form of the price' do
      row = page.find("a[href='/settings/prices/#{price.id}/edit']").ancestor('[data-controller="ui--table-row--component"]')

      aggregate_failures do
        expect(row['data-ui--table-row--component-form-sheet-value']).to eq('true')
        expect(row).to have_text('New tariff')
        expect(row).to have_text(%r{0\.08\s*/kWh})
      end
    end
  end

  context 'when an AI client wrote a price' do
    before do
      allow(vc_test_controller).to receive(:admin?).and_return(true)
      Price.create!(name:, starts_at: 2.days.ago, amount_per_kwh: 0.06)
      Price.create!(name:, starts_at: 1.day.ago, amount_per_kwh: 0.08, origin: :mcp)

      render_inline(component)
    end

    it 'marks only that price' do
      expect(page).to have_css('span[role="img"][data-controller="tooltip"] svg', count: 1)
    end
  end
end
