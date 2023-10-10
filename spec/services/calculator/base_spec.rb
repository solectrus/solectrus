describe Calculator::Base do
  let(:calculator) { described_class.new }

  describe '#build_method' do
    subject { calculator.public_send(method) }

    let(:method) { :foo }

    context 'when block is given' do
      before { calculator.build_method(method) { 42 } }

      it { is_expected.to eq(42) }
    end

    context 'when data is given' do
      let(:data) { { method => 42 } }

      before { calculator.build_method(method, data) }

      it { is_expected.to eq(42) }
    end

    context 'when neither data nor block is given' do
      it 'raises an ArgumentError' do
        expect { calculator.build_method(:foo) }.to raise_error(ArgumentError)
      end
    end

    context 'when both data and block are given' do
      it 'raises an ArgumentError' do
        expect do
          calculator.build_method(:foo, { foo: 42 }) { 42 }
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe '#build_method_from_array' do
    let(:method) { :foo }

    context 'when data is given' do
      let(:data) { [{ method => 42 }, { method => 43 }] }

      before { calculator.build_method_from_array(method, data) }

      it 'defines a method for sum' do
        expect(calculator.public_send(method)).to eq(85)
      end

      it 'defines a method for array' do
        expect(calculator.public_send("#{method}_array")).to eq([42, 43])
      end
    end
  end

  describe '#grid_power' do
    subject { calculator.grid_power }

    context 'when grid_power_plus > grid_power_minus' do
      before do
        calculator.build_method(:grid_power_plus) { 3_900 }
        calculator.build_method(:grid_power_minus) { 0 }
      end

      it { is_expected.to eq(-3_900) }
    end

    context 'when grid_power_plus < grid_power_minus' do
      before do
        calculator.build_method(:grid_power_plus) { 0 }
        calculator.build_method(:grid_power_minus) { 3_900 }
      end

      it { is_expected.to eq(3_900) }
    end
  end

  describe '#bat_power' do
    subject { calculator.bat_power }

    context 'when bat_power_plus > bat_power_minus' do
      before do
        calculator.build_method(:bat_power_plus) { 1_500 }
        calculator.build_method(:bat_power_minus) { 0 }
      end

      it { is_expected.to eq(1_500) }
    end

    context 'when bat_power_plus < bat_power_minus' do
      before do
        calculator.build_method(:bat_power_plus) { 0 }
        calculator.build_method(:bat_power_minus) { 1_500 }
      end

      it { is_expected.to eq(-1_500) }
    end
  end

  describe '#total_plus' do
    subject { calculator.total_plus }

    context 'when all is nil' do
      before do
        calculator.build_method(:grid_power_plus, {})
        calculator.build_method(:bat_power_minus, {})
        calculator.build_method(:inverter_power, {})
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#autarky' do
    subject { calculator.autarky }

    context 'with real data' do
      before do
        calculator.build_method(:house_power) { 6_800 }
        calculator.build_method(:wallbox_charge_power) { 0 }
        calculator.build_method(:grid_power_plus) { 3_900 }
      end

      it { is_expected.to eq(42.6) }
    end

    context 'with simple example' do
      before do
        calculator.build_method(:house_power) { 3_500 }
        calculator.build_method(:wallbox_charge_power) { 0 }
        calculator.build_method(:grid_power_plus) { 2_500 }
      end

      it { is_expected.to eq(28.6) }
    end

    context 'with rounding issues' do
      before do
        calculator.build_method(:house_power) { 317 }
        calculator.build_method(:wallbox_charge_power) { 0 }
        calculator.build_method(:grid_power_plus) { 308 }
      end

      it { is_expected.to eq(2.8) }
    end

    context 'with wallbox' do
      before do
        calculator.build_method(:house_power) { 500 }
        calculator.build_method(:wallbox_charge_power) { 9_000 }
        calculator.build_method(:grid_power_plus) { 5_000 }
      end

      it { is_expected.to eq(47.4) }
    end

    context 'with zero values' do
      before do
        calculator.build_method(:inverter_power) { 0 }
        calculator.build_method(:house_power) { 0 }
        calculator.build_method(:wallbox_charge_power) { 0 }
        calculator.build_method(:grid_power_plus) { 0 }
      end

      it { is_expected.to be_nil }
    end

    context 'with zero grid_power_plus (maybe caused by balcony power plant)' do
      before do
        calculator.build_method(:house_power) { 0 }
        calculator.build_method(:wallbox_charge_power) { 0 }
        calculator.build_method(:inverter_power) { 8_600 }
        calculator.build_method(:grid_power_plus) { 0 }
        calculator.build_method(:grid_power_minus) { 8_700 }
      end

      it { is_expected.to eq(100) }
    end

    describe '#current_state_ok' do
      subject { calculator.current_state_ok }

      context 'when false' do
        before { calculator.build_method(:current_state_ok) { false } }

        it { is_expected.to be(false) }
      end

      context 'when true' do
        before { calculator.build_method(:current_state_ok) { true } }

        it { is_expected.to be(true) }
      end
    end
  end
end
