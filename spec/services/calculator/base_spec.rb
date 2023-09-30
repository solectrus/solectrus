describe Calculator::Base do
  let(:calculator) { described_class.new }

  describe '#grid_power' do
    subject { calculator.grid_power }

    context 'when grid_power_plus > grid_power_minus' do
      before do
        calculator.build_context grid_power_plus: 3_900, grid_power_minus: 0
      end

      it { is_expected.to eq(-3_900) }
    end

    context 'when grid_power_plus < grid_power_minus' do
      before do
        calculator.build_context grid_power_minus: 3_900, grid_power_plus: 0
      end

      it { is_expected.to eq(3_900) }
    end
  end

  describe '#bat_power' do
    subject { calculator.bat_power }

    context 'when bat_power_plus > bat_power_minus' do
      before do
        calculator.build_context bat_power_plus: 1_500, bat_power_minus: 0
      end

      it { is_expected.to eq(1_500) }
    end

    context 'when bat_power_plus < bat_power_minus' do
      before do
        calculator.build_context bat_power_minus: 1_500, bat_power_plus: 0
      end

      it { is_expected.to eq(-1_500) }
    end
  end

  describe '#autarky' do
    subject { calculator.autarky }

    context 'with real data' do
      before do
        calculator.build_context house_power: 6_800,
                                 wallbox_charge_power: 0,
                                 grid_power_plus: 3_900
      end

      it { is_expected.to eq(42.6) }
    end

    context 'with simple example' do
      before do
        calculator.build_context house_power: 3_500,
                                 wallbox_charge_power: 0,
                                 grid_power_plus: 2_500
      end

      it { is_expected.to eq(28.6) }
    end

    context 'with rounding issues' do
      before do
        calculator.build_context house_power: 317,
                                 wallbox_charge_power: 0,
                                 grid_power_plus: 308
      end

      it { is_expected.to eq(2.8) }
    end

    context 'with wallbox' do
      before do
        calculator.build_context house_power: 500,
                                 wallbox_charge_power: 9_000,
                                 grid_power_plus: 5_000
      end

      it { is_expected.to eq(47.4) }
    end

    context 'with zero values' do
      before do
        calculator.build_context inverter_power: 0,
                                 house_power: 0,
                                 wallbox_charge_power: 0,
                                 grid_power_plus: 0
      end

      it { is_expected.to be_nil }
    end

    context 'with zero grid_power_plus (maybe caused by balcony power plant)' do
      before do
        calculator.build_context house_power: 0,
                                 wallbox_charge_power: 0,
                                 inverter_power: 8_600,
                                 grid_power_plus: 0,
                                 grid_power_minus: 8_700
      end

      it { is_expected.to eq(100) }
    end

    describe '#current_state_ok' do
      subject { calculator.current_state_ok }

      context 'when false' do
        before { calculator.build_context current_state_ok: false }

        it { is_expected.to be(false) }
      end

      context 'when true' do
        before { calculator.build_context current_state_ok: true }

        it { is_expected.to be(true) }
      end
    end
  end
end
