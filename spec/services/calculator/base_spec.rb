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

    context 'when modifier is to_f' do
      context 'when data is nil' do
        before { calculator.build_method(method, data, :to_f) }

        let(:data) { { method => nil } }

        it { is_expected.to eq(0.0) }
      end

      context 'when data is nil (and allowed)' do
        before { calculator.build_method(method, data, :to_f, allow_nil: true) }

        let(:data) { { method => nil } }

        it { is_expected.to be_nil }
      end
    end

    context 'when modifier is to_i' do
      context 'when data is Float' do
        before { calculator.build_method(method, data, :to_i) }

        let(:data) { { method => 3.5 } }

        it { is_expected.to eq(3) }
      end

      context 'when data is nil' do
        before { calculator.build_method(method, data, :to_i) }

        let(:data) { { method => nil } }

        it { is_expected.to eq(0) }
      end

      context 'when data is nil (and allowed)' do
        before { calculator.build_method(method, data, :to_i, allow_nil: true) }

        let(:data) { { method => nil } }

        it { is_expected.to be_nil }
      end
    end

    context 'when modifier is to_b' do
      context 'when data is nil' do
        before { calculator.build_method(method, data, :to_b) }

        let(:data) { { method => nil } }

        it { is_expected.to be(false) }
      end

      context 'when data is nil (and allowed)' do
        before { calculator.build_method(method, data, :to_b, allow_nil: true) }

        let(:data) { { method => nil } }

        it { is_expected.to be_nil }
      end
    end

    context 'when modifier is to_utf8' do
      context 'when data is nil' do
        before { calculator.build_method(method, data, :to_utf8) }

        let(:data) { { method => nil } }

        it { is_expected.to eq('') }
      end

      context 'when data is nil (and allowed)' do
        before do
          calculator.build_method(method, data, :to_utf8, allow_nil: true)
        end

        let(:data) { { method => nil } }

        it { is_expected.to be_nil }
      end
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
        expect(calculator.public_send(:"#{method}_array")).to eq([42, 43])
      end
    end

    context 'when data is missing' do
      let(:data) { [{ method => nil }, { method => nil }] }

      before { calculator.build_method_from_array(method, data) }

      it 'defines a method for sum (returning nil)' do
        expect(calculator.public_send(method)).to be_nil
      end

      it 'defines a method for array' do
        expect(calculator.public_send(:"#{method}_array")).to eq([nil, nil])
      end
    end
  end

  describe '#producing?' do
    subject { calculator.producing? }

    context 'when inverter_power is nil' do
      before { calculator.build_method(:inverter_power) { nil } }

      it { is_expected.to be_nil }
    end

    context 'when inverter_power is below 50' do
      before { calculator.build_method(:inverter_power) { 20 } }

      it { is_expected.to be(false) }
    end

    context 'when inverter_power is greater than 50' do
      before { calculator.build_method(:inverter_power) { 60 } }

      it { is_expected.to be(true) }
    end
  end

  describe '#inverter_power_percent' do
    subject { calculator.inverter_power_percent }

    context 'when inverter_power is nil' do
      before { calculator.build_method(:inverter_power) { nil } }

      it { is_expected.to be_nil }
    end

    context 'when total_plus is 0' do
      before do
        calculator.build_method(:total_plus) { 0 }
        calculator.build_method(:inverter_power) { 60 }
      end

      it { is_expected.to eq(0) }
    end

    context 'when total_plus is zero' do
      before do
        calculator.build_method(:inverter_power) { 60 }
        calculator.build_method(:total_plus) { 0 }
      end

      it { is_expected.to eq(0) }
    end

    context 'when inverter_power and total_plus are present' do
      before do
        calculator.build_method(:inverter_power) { 60 }
        calculator.build_method(:total_plus) { 100 }
      end

      it { is_expected.to eq(60) }
    end
  end

  describe '#feeding?' do
    subject { calculator.feeding? }

    context 'when grid_import_power is nil' do
      before { calculator.build_method(:grid_import_power) { nil } }

      it { is_expected.to be_nil }
    end

    context 'when grid_export_power is nil' do
      before do
        calculator.build_method(:grid_import_power) { 100 }
        calculator.build_method(:grid_export_power) { nil }
      end

      it { is_expected.to be_nil }
    end

    context 'when values are very small' do
      before do
        calculator.build_method(:grid_import_power) { 20 }
        calculator.build_method(:grid_export_power) { 30 }
      end

      it { is_expected.to be false }
    end

    context 'when minus > plus' do
      before do
        calculator.build_method(:grid_import_power) { 200 }
        calculator.build_method(:grid_export_power) { 300 }
      end

      it { is_expected.to be true }
    end

    context 'when minus < plus' do
      before do
        calculator.build_method(:grid_import_power) { 300 }
        calculator.build_method(:grid_export_power) { 200 }
      end

      it { is_expected.to be false }
    end
  end

  describe '#grid_power' do
    subject { calculator.grid_power }

    context 'when grid_import_power > grid_export_power' do
      before do
        calculator.build_method(:grid_import_power) { 3_900 }
        calculator.build_method(:grid_export_power) { 0 }
      end

      it { is_expected.to eq(-3_900) }
    end

    context 'when grid_import_power < grid_export_power' do
      before do
        calculator.build_method(:grid_import_power) { 0 }
        calculator.build_method(:grid_export_power) { 3_900 }
      end

      it { is_expected.to eq(3_900) }
    end
  end

  describe '#battery_power' do
    subject { calculator.battery_power }

    context 'when battery_charging_power > battery_discharging_power' do
      before do
        calculator.build_method(:battery_charging_power) { 1_500 }
        calculator.build_method(:battery_discharging_power) { 0 }
      end

      it { is_expected.to eq(1_500) }
    end

    context 'when battery_charging_power < battery_discharging_power' do
      before do
        calculator.build_method(:battery_charging_power) { 0 }
        calculator.build_method(:battery_discharging_power) { 1_500 }
      end

      it { is_expected.to eq(-1_500) }
    end
  end

  describe '#total_plus' do
    subject { calculator.total_plus }

    context 'when all is nil' do
      before do
        calculator.build_method(:grid_import_power, {})
        calculator.build_method(:battery_discharging_power, {})
        calculator.build_method(:inverter_power, {})
      end

      it { is_expected.to eq(0) }
    end
  end

  describe '#total_minus' do
    subject { calculator.total_minus }

    context 'when all is nil' do
      before do
        calculator.build_method(:grid_export_power, {})
        calculator.build_method(:battery_charging_power, {})
        calculator.build_method(:house_power, {})
        calculator.build_method(:wallbox_power, {})
        calculator.build_method(:heatpump_power, {})
      end

      it { is_expected.to eq(0) }
    end

    context 'when values are present' do
      before do
        calculator.build_method(:grid_export_power) { 1 }
        calculator.build_method(:battery_charging_power) { 2 }
        calculator.build_method(:house_power) { 3 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 4 }
      end

      it { is_expected.to eq(10) }
    end
  end

  describe '#autarky' do
    subject { calculator.autarky }

    context 'with real data' do
      before do
        calculator.build_method(:house_power) { 6_800 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 0 }
        calculator.build_method(:grid_import_power) { 3_900 }
      end

      it { is_expected.to eq(42.6) }
    end

    context 'with simple example' do
      before do
        calculator.build_method(:house_power) { 3_500 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 0 }
        calculator.build_method(:grid_import_power) { 2_500 }
      end

      it { is_expected.to eq(28.6) }
    end

    context 'with rounding issues' do
      before do
        calculator.build_method(:house_power) { 317 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 0 }
        calculator.build_method(:grid_import_power) { 308 }
      end

      it { is_expected.to eq(2.8) }
    end

    context 'with wallbox' do
      before do
        calculator.build_method(:house_power) { 500 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 9_000 }
        calculator.build_method(:grid_import_power) { 5_000 }
      end

      it { is_expected.to eq(47.4) }
    end

    context 'with zero values' do
      before do
        calculator.build_method(:inverter_power) { 0 }
        calculator.build_method(:house_power) { 0 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 0 }
        calculator.build_method(:grid_import_power) { 0 }
      end

      it { is_expected.to be_nil }
    end

    context 'with zero grid_import_power (maybe caused by balcony heatpump_power plant)' do
      before do
        calculator.build_method(:house_power) { 0 }
        calculator.build_method(:heatpump_power) { 0 }
        calculator.build_method(:wallbox_power) { 0 }
        calculator.build_method(:inverter_power) { 8_600 }
        calculator.build_method(:grid_import_power) { 0 }
        calculator.build_method(:grid_export_power) { 8_700 }
      end

      it { is_expected.to eq(100) }
    end

    describe '#system_status_ok' do
      subject { calculator.system_status_ok }

      context 'when false' do
        before { calculator.build_method(:system_status_ok) { false } }

        it { is_expected.to be(false) }
      end

      context 'when true' do
        before { calculator.build_method(:system_status_ok) { true } }

        it { is_expected.to be(true) }
      end
    end
  end
end
