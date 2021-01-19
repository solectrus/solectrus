describe BaseCalculator do
  let(:calculator) { described_class.new }

  describe '#autarky' do
    subject { calculator.autarky.round(1) }

    context 'with real data' do
      before do
        calculator.build_context house_power:          6_800,
                                 wallbox_charge_power: 0,
                                 grid_power_plus:      3_900
      end

      it { is_expected.to eq(42.6) }
    end

    context 'with simple example' do
      before do
        calculator.build_context house_power:          3_500,
                                 wallbox_charge_power: 0,
                                 grid_power_plus:      2_500
      end

      it { is_expected.to eq(28.6) }
    end

    context 'with rounding issues' do
      before do
        calculator.build_context house_power:          317,
                                 wallbox_charge_power: 0,
                                 grid_power_plus:      308
      end

      it { is_expected.to eq(2.8) }
    end

    context 'with wallbox' do
      before do
        calculator.build_context house_power:          500,
                                 wallbox_charge_power: 9_000,
                                 grid_power_plus:      5_000
      end

      it { is_expected.to eq(47.4) }
    end
  end
end
