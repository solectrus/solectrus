describe Amortization::Table::Component, type: :component do
  subject(:html) { render_inline(described_class.new(result: AmortizationCalculator.new.result)) }

  # Two full PV years measured, the third one runs and is projected
  before do
    travel_to Date.new(2024, 6, 15)
    Summary.delete_all
    CashFlow.create!(date: Date.new(2021, 7, 10), amount: -300, note: 'PV')

    36.times do |index|
      create_summary(
        date: Date.new(2021, 7, 10) + index.months,
        values: [
          [:house_power, :sum, 10_000],
          [:grid_import_power, :sum, 0],
          [:grid_export_power, :sum, 0],
        ],
      )
    end
  end

  def rows = html.css('.table-row-group > .table-row')

  it 'links the savings of a measured year to the balance page of that PV year' do
    expect(html.css('a[href="/savings/2021-07-10..2022-07-09"]')).to be_present
  end

  it 'sets the first projected year off with a dashed rule' do
    ruled = rows.map { |row| row.css('.border-dashed').any? }

    expect(ruled.count(true)).to eq(1)
    expect(ruled.index(true)).to be_positive
  end
end
