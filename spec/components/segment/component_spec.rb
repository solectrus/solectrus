describe Segment::Component, type: :component do
  subject(:component) { described_class.new(sensor, parent:, peak: nil) }

  before do
    create_summary(
      date: timeframe.date,
      updated_at:,
      values: [[sensor, :sum, 1234]],
    )
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
      calculations: [Queries::Calculation.new(:house_power, :sum, :sum)],
    )
  end
  let(:updated_at) { 3.minutes.ago }

  it 'renders' do
    result = render_inline(component)

    expect(result.to_html).to include("data-time=\"#{updated_at.to_i}\"")
    expect(result.to_html).to include('data-value="1234.0"')
  end
end
