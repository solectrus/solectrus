describe BalanceGap::Component, type: :component do
  subject(:component) { described_class.new(data:) }

  let(:data) { PowerBalance.new(Sensor::Data::Single.new(raw_data, timeframe:)) }
  let(:timeframe) { Timeframe.new(Date.current.strftime('%Y-%m')) }

  # Sources and sinks match, so every consumer is recorded exactly once
  let(:raw_data) do
    {
      %i[grid_costs sum] => 45.0,
      %i[inverter_power sum] => 10_000.0,
      %i[grid_import_power sum] => 5_000.0,
      %i[grid_export_power sum] => 3_000.0,
      %i[house_power sum] => 12_000.0,
      %i[wallbox_power sum] => 0.0,
      %i[heatpump_power sum] => 0.0,
      %i[battery_charging_power sum] => 0.0,
      %i[battery_discharging_power sum] => 0.0,
    }
  end

  it 'renders nothing' do
    render_inline(component)

    expect(page).to have_no_css '.balance-gap'
  end

  # The tooltip sits in a <template>, which the parsed page drops -- so its
  # content is read from the raw markup
  context 'when a consumer is missing from the measurement' do
    # 2 kWh of the consumption are missing, priced with 45 EUR / 5 kWh
    let(:raw_data) { super().merge(%i[house_power sum] => 10_000.0) }

    it 'renders the badge' do
      render_inline(component)

      expect(page).to have_css '.balance-gap'
    end

    it 'names both sides and their difference' do
      render_inline(component)

      expect(rendered_content).to include('15.0 kWh') # sources
      expect(rendered_content).to include('13.0 kWh') # sinks
      expect(rendered_content).to include('2.0 kWh') # difference
      expect(rendered_content).to include('13 %') # share
    end

    it 'says what it means for the sensors' do
      render_inline(component)

      expect(rendered_content).to include('too high on the source side')
      expect(rendered_content).to include('too low on the usage side')
    end
  end

  # Rounded on their own, 15,04 - 13,06 = 1,98 shows as 15,0 - 13,1 = 2,0
  context 'with values that round away from the difference' do
    let(:raw_data) do
      super().merge(%i[grid_import_power sum] => 5_040.0, %i[house_power sum] => 10_060.0)
    end

    it 'shows values that add up' do
      sources, sinks, difference =
        [component.sources, component.sinks, component.difference].map(&:to_f)

      expect((sources - sinks).round(1)).to eq(difference)
      expect(difference).to eq(2.0)
    end
  end

  # In the unit of the difference, 6 kWh would show as 6000 Wh
  context 'with a difference below one kWh' do
    let(:raw_data) do
      super().merge(
        %i[inverter_power sum] => 5_000.0,
        %i[grid_import_power sum] => 1_000.0,
        %i[grid_export_power sum] => 1_000.0,
        %i[house_power sum] => 4_300.0,
      )
    end

    it 'keeps all three in kWh' do
      expect(component.sources).to eq('6.0 kWh')
      expect(component.sinks).to eq('5.3 kWh')
      expect(component.difference).to eq('0.7 kWh')
    end
  end

  # In the unit of the sides, 80 kWh would show as 0.1 MWh
  context 'with sides much larger than the difference' do
    let(:raw_data) do
      super().merge(
        %i[inverter_power sum] => 1_000_000.0,
        %i[grid_import_power sum] => 500_000.0,
        %i[grid_export_power sum] => 300_000.0,
        %i[house_power sum] => 1_120_000.0,
      )
    end

    it 'keeps the digits of the difference' do
      expect(component.difference).to eq('80.0 kWh')
    end
  end

  context 'when a consumption is counted twice' do
    let(:raw_data) { super().merge(%i[house_power sum] => 14_000.0) }

    it 'says what it means for the sensors' do
      render_inline(component)

      expect(page).to have_css '.balance-gap'
      expect(rendered_content).to include('too high on the usage side')
      expect(rendered_content).to include('too low on the source side')
    end
  end

  context 'when the difference stays below the threshold' do
    # 600 Wh of 15 kWh is 4 %, just short of what counts as a finding
    let(:raw_data) { super().merge(%i[house_power sum] => 11_400.0) }

    it 'renders nothing' do
      render_inline(component)

      expect(page).to have_no_css '.balance-gap'
    end
  end
end
