describe ChartDropdown::Selector::Component, type: :component do
  subject(:component) do
    described_class.new(sensor_name:, timeframe:, sensor_names:, menu_config:)
  end

  let(:timeframe) { Timeframe.new('2024') }
  let(:sensor_name) { :inverter_power }
  let(:sensor_names) { %i[inverter_power house_power] }
  let(:menu_config) { {} }

  def render_selector
    with_controller_class(Balance::ChartsController) do
      with_request_url("/charts/#{sensor_name}/2024") do
        render_inline(component)
      end
    end
  end

  # A combined chart is offered as each of its halves (see `chart entries:`)
  describe '#display_name' do
    context 'with a half of a combined chart' do
      let(:sensor_name) { :grid_import_power }

      it 'names the other half too' do
        import = Sensor::Registry[:grid_import_power].display_name
        export = Sensor::Registry[:grid_export_power].display_name

        expect(component.display_name).to eq("#{import} (& #{export})")
      end
    end

    context 'with a sensor of its own chart' do
      it 'names the sensor alone' do
        expect(component.display_name).to eq(
          Sensor::Registry[:inverter_power].display_name,
        )
      end
    end
  end

  describe '#sensor_items' do
    context 'with sensors of several groups' do
      it 'gives the items of the first group' do
        render_selector

        expect(component).to be_grouped
        expect(component.sensor_items.map(&:key)).to eq(%i[inverter_power])
      end
    end

    context 'without grouping' do
      let(:menu_config) { { grouped: false } }

      it 'gives all items' do
        render_selector

        expect(component.sensor_items.map(&:key)).to contain_exactly(
          :inverter_power,
          :house_power,
        )
      end
    end
  end

  # Without a list of items, the menu draws a line before the named sensors
  context 'with a separator before a sensor' do
    let(:menu_config) { { grouped: false, separator_before: %i[house_power] } }

    it 'draws a line above that sensor alone' do
      render_selector

      house = page.find('[role="menu"] a[href*="house_power"]', visible: :all)
      inverter = page.find('[role="menu"] a[href*="inverter_power"]', visible: :all)

      aggregate_failures do
        expect(house[:class]).to include('border-t')
        expect(inverter[:class]).not_to include('border-t')
      end
    end
  end
end
