describe PriceList::Component, type: :component do
  subject(:component) { described_class.new(prices:, name:) }

  let(:name) { 'feed_in' }
  let(:prices) { Price.list_for(name) }

  context 'when there is a price of zero' do
    before do
      Price.create!(name:, starts_at: 2.days.ago, value: 0)
      Price.create!(name:, starts_at: 1.day.ago, value: 0.08)

      render_inline(component)
    end

    it 'renders component' do
      expect(page).to have_css '.table'
    end
  end

  context 'when all prices are non-zero' do
    before do
      Price.create!(name:, starts_at: 2.days.ago, value: 0.06)
      Price.create!(name:, starts_at: 1.day.ago, value: 0.08)

      render_inline(component)
    end

    it 'renders component with calculated change' do
      expect(page).to have_css '.table', text: '&plus; 33 %'
    end
  end
end
