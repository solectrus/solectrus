describe Amortization::Stats::Component, type: :component do
  subject(:html) { render_inline(described_class.new(result: AmortizationCalculator.new.result)) }

  before do
    travel_to Date.new(2024, 6, 15)
    Summary.delete_all
    CashFlow.create!(date: Date.new(2023, 8, 1), amount: -300, note: 'PV')
  end

  def net_investment_hint = html.css('[data-tooltip-target="html"]').first.text.squish

  it 'explains the net investment alone without a subsidy' do
    expect(net_investment_hint).not_to include('minus subsidy/refund')
  end

  context 'with a subsidy' do
    before do
      CashFlow.create!(date: Date.new(2023, 9, 1), amount: 100, category: :subsidy, note: 'Grant')
    end

    it 'breaks the net investment down into the gross investment and the subsidy' do
      expect(net_investment_hint).to include('Gross investment € 300 minus subsidy/refund € 100.')
    end
  end
end
