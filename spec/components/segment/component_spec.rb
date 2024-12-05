describe Segment::Component, type: :component do
  subject(:component) { described_class.new(sensor, parent:, peak: nil) }

  before do
    Summary.create!(date: timeframe.date, updated_at:, "sum_#{sensor}" => 1234)
  end

  let(:sensor) { :house_power }
  let(:parent) do
    SegmentContainer::Component.new tippy_placement: 'right',
                                    calculator:,
                                    timeframe:
  end
  let(:timeframe) { Timeframe.day }
  let(:calculator) do
    Calculator::Range.new(
      timeframe,
      calculations: {
        house_power: :sum_house_power_sum,
      },
    )
  end
  let(:updated_at) { 3.minutes.ago }

  it 'renders' do
    result = render_inline(component)

    expect(result.to_html).to include("data-time=\"#{updated_at.to_i}\"")
    expect(result.to_html).to include('data-value="1.234"')
  end
end
