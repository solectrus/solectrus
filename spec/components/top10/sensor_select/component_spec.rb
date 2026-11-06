describe Top10::SensorSelect::Component, type: :component do
  subject(:component) do
    described_class.new(
      current_sensor: Sensor::Registry[:inverter_power],
      permitted_params: { controller: 'top10', period: 'day', calc: 'sum', sort: 'desc' },
    )
  end

  # The names of the groups of the menu
  let(:group_names) do
    render_inline(component)
    component.sensor_groups.pluck(:name)
  end

  context 'with several inverters' do
    it 'keeps generation, grid and battery apart' do
      expect(group_names).to include(I18n.t('categories.inverter'), I18n.t('categories.grid'))
      expect(group_names).not_to include(I18n.t('categories.generation_grid_battery'))
    end
  end

  context 'with a single inverter' do
    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_INVERTER_POWER' => 'my-pv:inverter_power',
          'INFLUX_SENSOR_INVERTER_POWER_1' => '',
          'INFLUX_SENSOR_INVERTER_POWER_2' => '',
        ),
      )
    end

    after { Sensor::Config.setup(ENV) }

    it 'combines generation, grid and battery into the first group' do
      expect(group_names.first).to eq(I18n.t('categories.generation_grid_battery'))
      expect(group_names).not_to include(I18n.t('categories.inverter'), I18n.t('categories.grid'))
    end
  end
end
