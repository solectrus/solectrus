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

    # The long press then opens the tooltip itself
    context 'without the permission' do
      let(:sensor_name) { :battery_charging_power }

      before { stub_feature }

      it { is_expected.to be_nil }
    end
  end

  # A long press on a segment shows its details, not the trends of the page
  describe '#sensor_insights_path with a sensor of the trend overview' do
    subject(:path) { helper.sensor_insights_path(Sensor::Registry[:heatpump_power], timeframe: Timeframe.new(timeframe)) }

    let(:timeframe) { '2026-01' }

    before do
      travel_to Date.new(2026, 3, 1)
      stub_feature(:trends)
      allow(helper).to receive(:controller_namespace).and_return('balance')
    end

    it { is_expected.to eq('/insights/heatpump_power/2026-01') }
  end

  describe '#page_trends_path' do
    subject(:path) { helper.page_trends_path(timeframe: Timeframe.new(timeframe)) }

    let(:timeframe) { '2026-01' }
    let(:controller_name) { 'home' }
    let(:controller_namespace) { 'house' }

    before do
      travel_to Date.new(2026, 3, 1)
      stub_feature(:trends)
      allow(helper).to receive_messages(controller_name:, controller_namespace:, selection_params: {})
      helper.define_singleton_method(:sensor_name) { :house_power }
      helper.define_singleton_method(:admin?) { false }
    end

    it { is_expected.to eq('/trends/2026-01') }

    context 'with a week' do
      let(:timeframe) { '2026-W02' }

      it { is_expected.to be_nil }
    end

    context 'with the whole time' do
      let(:timeframe) { 'all' }

      it { is_expected.to eq('/trends/all') }
    end

    # The sheet then shows a teaser (see TrendsController)
    context 'without the permission' do
      before { stub_feature }

      it { is_expected.to eq('/trends/2026-01') }
    end

    context 'with the live view' do
      let(:timeframe) { 'now' }

      it { is_expected.to be_nil }
    end

    context 'with a page beside the home page' do
      let(:controller_name) { 'savings' }

      it { is_expected.to be_nil }
    end

    # A visitor of the car page sees the days up to two days ago, so the
    # third day of a month shows one day only
    context 'with a visitor of the car page' do
      let(:controller_namespace) { 'cars' }
      let(:timeframe) { '2026-03' }

      before { travel_to Date.new(2026, 3, 3) }

      it { is_expected.to be_nil }

      it 'offers the trends to the admin' do
        helper.define_singleton_method(:admin?) { true }

        expect(path).to eq('/trends/2026-03')
      end
    end
  end
end
