describe Segment::Component, type: :component do
  subject(:component) do
    described_class.new(
      sensor,
      parent:
        SegmentContainer::Component.new(
          tippy_placement: 'right',
          data:,
          timeframe:,
        ),
    )
  end

  before do
    create_summary(
      date: timeframe.date,
      updated_at:,
      values: [[sensor_name, :sum, 1234]],
    )
  end

  let(:sensor) { Sensor::Registry[:house_power] }
  let(:sensor_name) { sensor.name }
  let(:timeframe) { Timeframe.day }
  let(:data) do
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          sensor_name => 1_234,
          :wallbox_power => 10,
          :heatpump_power => 10,
          :battery_charging_power => 10,
          :grid_export_power => 10,
          :house_costs => 5.0,
          :house_costs_grid => 3.0,
          :house_costs_pv => 2.0,
        },
        timeframe:,
        time: updated_at,
      ),
    )
  end
  let(:updated_at) { 3.minutes.ago }

  it 'renders' do
    result = render_inline(component)

    expect(result.to_html).to include("data-time=\"#{updated_at.to_i}\"")
    expect(result.to_html).to include('data-value="1234.0"')
  end
end
