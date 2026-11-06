describe Car::PaymentList::Component, type: :component do
  subject(:html) do
    render_inline(described_class.new(payments: Car::Payment.none, pagy: nil, total: 0, cars: [Car.new(id: 1)], filter:))
  end

  context 'without a filter' do
    let(:filter) { Car::PaymentFilter.new }

    it 'introduces the payments' do
      expect(html.text).to include('No payments yet')
    end
  end

  context 'with a filter' do
    let(:filter) { Car::PaymentFilter.new(categories: %w[insurance]) }

    it 'says that no payment matches' do
      expect(html.text).to include('No payments match this filter')
      expect(html.text).not_to include('No payments yet')
    end
  end
end
