describe SensorPathHelper do
  describe '#sensor_home_path' do
    subject(:path) { helper.sensor_home_path(sensor_name, timeframe: '2026') }

    context 'with a sensor of the power balance' do
      let(:sensor_name) { :house_power }

      it { is_expected.to eq('/house_power/2026') }
    end

    context 'with a sensor of another page' do
      let(:sensor_name) { :house_power_without_custom }

      it { is_expected.to eq('/house/house_power_without_custom/2026') }
    end

    # The point of the helper: the target page must really show the sensor,
    # otherwise it redirects to its own default and the click goes nowhere.
    context 'when the settings switch the page off' do
      let(:sensor_name) { :heatpump_cop }

      before { allow(Setting).to receive(:enable_heatpump).and_return(false) }

      it { is_expected.to eq('/heatpump_cop/2026') }
    end
  end

  describe '#sensor_insights_path' do
    subject(:path) do
      helper.sensor_insights_path(Sensor::Registry[sensor_name], timeframe:)
    end

    let(:timeframe) { Timeframe.new('2026-01') }

    context 'with a sensor that has a trend' do
      let(:sensor_name) { :battery_charging_power }

      it { is_expected.to eq('/insights/battery_charging_power/2026-01') }
    end

    context 'with the current values' do
      let(:sensor_name) { :battery_charging_power }
      let(:timeframe) { Timeframe.now }

      it { is_expected.to be_nil }
    end

    context 'with a sensor without a trend' do
      let(:sensor_name) { :house_power_without_custom }

      it { is_expected.to be_nil }
    end
  end
end
