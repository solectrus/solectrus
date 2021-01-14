describe BaseCalculator do
  let(:calculator) { described_class.new }

  describe '#autarky' do
    subject { calculator.autarky.round }

    context 'when today' do
      before do
        calculator.build_context inverter_power:       4.5,
                                 house_power:          6.8,
                                 grid_power_plus:      3.9, grid_power_minus: 0.1,
                                 bat_power_minus:      0.3, bat_power_plus:   1.7,
                                 wallbox_charge_power: 0.0
      end

      it { is_expected.to eq(43) }
    end

    context 'when example' do
      before do
        calculator.build_context inverter_power:       2500,
                                 house_power:          3500,
                                 grid_power_plus:      2500, grid_power_minus: 1500,
                                 bat_power_minus:      0,    bat_power_plus:    0,
                                 wallbox_charge_power: 0
      end

      it { is_expected.to eq(29) }
    end
  end
end
