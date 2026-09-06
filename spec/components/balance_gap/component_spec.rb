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
      expect(rendered_content).to include('+13 %') # share
    end

    it 'says what it means for the sensors' do
      render_inline(component)

      expect(rendered_content).to include('a consumer is missing')
      expect(rendered_content).to include('a source measures too high')
    end
  end

  context 'when a consumption is counted twice' do
    let(:raw_data) { super().merge(%i[house_power sum] => 14_000.0) }

    it 'says what it means for the sensors' do
      render_inline(component)

      expect(page).to have_css '.balance-gap'
      expect(rendered_content).to include('recorded too high')
      expect(rendered_content).to include('a source is missing')
    end

    context 'when the installation has a battery' do
      before { allow(data).to receive(:battery?).and_return(true) }

      it 'names the loss of the battery as a cause as well' do
        render_inline(component)

        expect(rendered_content).to include('loss of the battery')
      end
    end

    context 'when the installation has no battery' do
      before { allow(data).to receive(:battery?).and_return(false) }

      it 'says nothing about a battery' do
        render_inline(component)

        expect(rendered_content).not_to include('loss of the battery')
      end
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
