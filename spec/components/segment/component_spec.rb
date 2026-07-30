describe Segment::Component, type: :component do
  subject(:component) do
    described_class.new(
      sensor,
      parent:
        SegmentContainer::Component.new(
          tooltip_placement: 'right',
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
        times: { sensor_name => updated_at },
      ),
    )
  end
  let(:updated_at) { 3.minutes.ago }

  it 'renders' do
    result = render_inline(component)

    expect(result.to_html).to include("data-time=\"#{updated_at.to_i}\"")
    expect(result.to_html).to include('data-value="1234.0"')
  end

  # The charging segment shows a grid share but no amount of its own, so it
  # carries a note instead. It is rendered from a sidecar translation, which has
  # to exist for every sensor in the noted list.
  context 'with a battery charge holding grid electricity' do
    subject(:html) { render_inline(component).to_html }

    let(:sensor) { Sensor::Registry[:battery_charging_power] }
    let(:data) do
      PowerBalance.new(
        Sensor::Data::Single.new(
          {
            sensor_name => 1_000,
            :inverter_power => 2_000,
            :grid_import_power => 100,
            :house_power => 500,
            :wallbox_power => 10,
            :heatpump_power => 10,
            :grid_export_power => 10,
            :battery_charging_power_grid => 400,
          },
          timeframe:,
          times: { sensor_name => updated_at },
        ),
      )
    end

    before { stub_feature(:power_splitter) }

    it 'shows the grid share' do
      expect(html).to include('40')
    end

    it 'explains where the costs went' do
      render_inline(component)

      expect(component.costs_note).to be_present
    end

    it 'has a translation for the note' do
      expect(html).not_to include('translation missing')
    end
  end

  # The discharge's grid share is an attribution from the Power Splitter's
  # ledger rather than something the battery does at that moment. On the source
  # side, next to the grid import, it would read as a grid draw that is not
  # happening -- so the segment stays undivided.
  context 'with a battery discharge holding grid electricity' do
    let(:sensor) { Sensor::Registry[:battery_discharging_power] }
    let(:data) do
      PowerBalance.new(
        Sensor::Data::Single.new(
          {
            sensor_name => 1_000,
            :inverter_power => 2_000,
            :grid_import_power => 100,
            :house_power => 500,
            :wallbox_power => 10,
            :heatpump_power => 10,
            :battery_charging_power => 10,
            :grid_export_power => 10,
            :battery_discharging_power_grid => 400,
          },
          timeframe:,
          times: { sensor_name => updated_at },
        ),
      )
    end

    before { stub_feature(:power_splitter) }

    it 'shows neither a grid share nor a note' do
      render_inline(component)

      expect(component.power_grid_ratio).to be_nil
      expect(component.costs_note).to be_nil
    end
  end
end
