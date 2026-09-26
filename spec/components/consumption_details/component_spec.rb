describe ConsumptionDetails::Component, type: :component do
  def values_shown(inverter_power, grid_export_power, self_consumption)
    render_inline(
      described_class.new(
        data:
          Sensor::Data::Single.new(
            { inverter_power:, grid_export_power:, self_consumption:, self_consumption_quote: 29 },
            timeframe: Timeframe.day,
          ),
        timeframe: Timeframe.day,
      ),
    )

    page.all('.sensor-value').map(&:text)
  end

  # The minus stands in the label, so the grid export shows as it is
  it 'shows the grid export without a sign' do
    expect(values_shown(904_032, 641_887, 262_145)).to include(a_string_starting_with('641'))
  end

  # The self-consumption never drops below zero, so the export keeps its value
  it 'keeps the grid export when it exceeds the generation' do
    expect(values_shown(20_000, 30_000, 0).first(3)).to match(
      [a_string_starting_with('20'), a_string_starting_with('30'), a_string_starting_with('0')],
    )
  end
end
