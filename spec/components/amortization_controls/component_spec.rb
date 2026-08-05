describe AmortizationControls::Component, type: :component do
  # The period slider; the rate slider is the plain case and needs no example.
  def period_slider(rendered)
    rendered.css("input[name='amortization[period_years]']")
  end

  # Asked of the calculator rather than spelled out, because the minimum
  # depends on the age of the system - see the example below.
  it 'offers the periods the calculation accepts' do
    range = AmortizationCalculator.period_range
    slider =
      period_slider(
        render_inline(described_class.new(period_years: 20, interest_rate: 3.0)),
      )

    aggregate_failures do
      expect(slider.attr('min').value).to eq(range.min.to_s)
      expect(slider.attr('max').value).to eq(range.max.to_s)
      expect(slider.attr('value').value).to eq('20')
    end
  end

  # The minimum rises with the age of the system, and the thumb must not sit
  # outside its own track: whatever a caller hands in, the slider shows the
  # period the calculation would actually use.
  it 'shows the raised minimum when the system has outgrown the period' do
    travel_to Date.new(2035, 6, 1) do
      slider =
        period_slider(
          render_inline(
            described_class.new(period_years: 10, interest_rate: 3.0),
          ),
        )

      aggregate_failures do
        expect(slider.attr('min').value).to eq('15')
        expect(slider.attr('value').value).to eq('15')
      end
    end
  end
end
