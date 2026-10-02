describe Car::CalculationTooltip::Component, type: :component do
  subject(:html) { render_inline(described_class.new(**arguments)) }

  def row(operator, label, value)
    described_class::Row.new(operator:, label:, value: SensorValue::Component.new(value, :total_costs))
  end

  let(:arguments) do
    {
      terms: [row(nil, 'Cost', 12), row('÷', 'Distance', 4)],
      result: row('=', 'Rate', 3),
      notes: ['A note'],
    }
  end

  it 'shows the terms, a line and the result' do
    # The operator and the label of each row
    rows = html.css('tr').map { |row| row.css('td').first(2).map { it.text.squish } }

    expect(rows).to eq([['', 'Cost'], %w[÷ Distance], [''], %w[= Rate]])
  end

  it 'separates the notes from the calculation' do
    expect(html.css('.label-value-separator p').map(&:text)).to eq(['A note'])
  end

  context 'without terms' do
    let(:arguments) { { notes: ['No data'] } }

    it 'shows the notes alone' do
      expect(html.css('table')).to be_empty
      expect(html.css('.label-value-separator')).to be_empty
      expect(html.text).to include('No data')
    end
  end
end
