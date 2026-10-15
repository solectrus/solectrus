describe Price::List::Change::Component, type: :component do
  subject(:component) { described_class.new(price:, previous:) }

  let(:price) { Price.new(name:, amount_per_kwh: 0.33) }
  let(:previous) { Price.new(name:, amount_per_kwh: 0.30) }

  before { render_inline(component) }

  context 'when the electricity price rises' do
    let(:name) { 'electricity' }

    it 'shows the change as bad' do
      expect(page).to have_css('span.text-signal-negative', text: /10 %/)
    end
  end

  context 'when the feed-in tariff rises' do
    let(:name) { 'feed_in' }

    it 'shows the change as good' do
      expect(page).to have_css('span.text-signal-positive', text: /10 %/)
    end
  end

  context 'without a previous price' do
    let(:name) { 'electricity' }
    let(:previous) { nil }

    it 'renders nothing' do
      expect(page.text).to be_empty
    end
  end

  context 'when the previous price is zero' do
    let(:name) { 'feed_in' }
    let(:previous) { Price.new(name:, amount_per_kwh: 0) }

    it 'renders nothing' do
      expect(page.text).to be_empty
    end
  end
end
