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
end
