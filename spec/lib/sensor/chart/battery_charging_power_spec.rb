describe Sensor::Chart::BatteryChargingPower do
  let(:chart) { described_class.new(timeframe:) }

  def style_for(sensor_name)
    chart.__send__(:style_for_sensor, Sensor::Registry[sensor_name])
  end

  context 'with the power splitter, on a day' do
    let(:timeframe) { Timeframe.new('2025-01-06') }

    before { stub_feature(:power_splitter) }

    it 'splits the charging into its grid and PV share' do
      expect(chart.__send__(:chart_sensor_names)).to eq(
        %i[
          battery_charging_power_grid
          battery_charging_power_pv
          battery_discharging_power
        ],
      )
    end

    it 'stacks the areas on the value axis' do
      expect(chart.options.dig(:scales, :y, :stacked)).to be true
    end

    it 'fills the PV area down to the grid area, not to the zero line' do
      expect(style_for(:battery_charging_power_pv)[:fill]).to eq('-1')
      expect(style_for(:battery_charging_power_grid)[:fill]).to be true
    end

    it 'keeps the gradient by leaving the areas without a stack group' do
      expect(style_for(:battery_charging_power_pv)).not_to include(:stack)
      expect(style_for(:battery_charging_power_pv)[:noGradient]).to be false
    end

    it 'declares that the fills do not cover each other' do
      expect(chart.__send__(:overlapping_datasets?)).to be false
    end
  end

  context 'with the power splitter, on a month' do
    let(:timeframe) { Timeframe.new('2025-01') }

    before { stub_feature(:power_splitter) }

    it 'stacks the bars through their stack group instead' do
      expect(style_for(:battery_charging_power_pv)[:stack]).to be true
      expect(style_for(:battery_charging_power_pv)[:fill]).to be true
    end
  end

  context 'without the power splitter' do
    let(:timeframe) { Timeframe.new('2025-01-06') }

    before { stub_feature }

    it 'draws the plain charging and discharging series' do
      expect(chart.__send__(:chart_sensor_names)).to eq(
        %i[battery_charging_power battery_discharging_power],
      )
    end

    it 'leaves the overlap decision to the frontend' do
      expect(chart.__send__(:overlapping_datasets?)).to be_nil
    end
  end
end
