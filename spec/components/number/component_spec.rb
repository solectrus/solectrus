describe Number::Component do
  let(:component) { described_class.new(value:) }

  describe 'to_watt_hour' do
    subject(:to_watt_hour) { component.to_watt_hour(precision:) }

    let(:precision) { nil }

    context 'when small number (< 100 kWh)' do
      let(:value) { 12_345.67 }

      it 'renders kWh with decimal' do
        expect(
          to_watt_hour,
        ).to eq '<span><strong class="font-medium">12</strong><small>.3</small>&nbsp;<small>kWh</small></span>'
      end
    end

    context 'when large number (>= 100 kWh)' do
      let(:value) { 123_456.78 }

      it 'renders kWh without decimal' do
        expect(
          to_watt_hour,
        ).to eq '<span><strong class="font-medium">123</strong>&nbsp;<small>kWh</small></span>'
      end
    end

    context 'when very large number (>= 1000 kWh)' do
      let(:value) { 1_234_567.89 }

      it 'renders MWh' do
        expect(
          to_watt_hour,
        ).to eq '<span><strong class="font-medium">1</strong><small>.2</small>&nbsp;<small>MWh</small></span>'
      end
    end

    context 'when large number with precision' do
      let(:value) { 123_456.78 }
      let(:precision) { 3 }

      it 'renders kWh with decimal places' do
        expect(
          to_watt_hour,
        ).to eq '<span><strong class="font-medium">123</strong><small>.457</small>&nbsp;<small>kWh</small></span>'
      end
    end
  end

  describe 'to_watt' do
    subject(:to_watt) { component.to_watt(precision:) }

    let(:precision) { nil }

    context 'when small number (< 100 kW)' do
      let(:value) { 12_345.67 }

      it 'renders kW' do
        expect(
          to_watt,
        ).to eq '<span><strong class="font-medium">12</strong><small>.3</small>&nbsp;<small>kW</small></span>'
      end
    end

    context 'when large number (>= 100 kW)' do
      let(:value) { 123_456.78 }

      it 'renders kW' do
        expect(
          to_watt,
        ).to eq '<span><strong class="font-medium">123</strong>&nbsp;<small>kW</small></span>'
      end
    end

    context 'when very large number (>= 1000 kW)' do
      let(:value) { 1_234_567.89 }

      it 'renders MW' do
        expect(
          to_watt,
        ).to eq '<span><strong class="font-medium">1</strong><small>.2</small>&nbsp;<small>MW</small></span>'
      end
    end

    context 'when large number with precision' do
      let(:value) { 123_456.78 }
      let(:precision) { 3 }

      it 'renders kW with decimal places' do
        expect(
          to_watt,
        ).to eq '<span><strong class="font-medium">123</strong><small>.457</small>&nbsp;<small>kW</small></span>'
      end
    end
  end

  describe 'to_eur' do
    subject(:to_eur) { component.to_eur(**options) }

    let(:options) { {} }

    context 'when positive' do
      let(:value) { 1.234 }

      it do
        expect(
          to_eur,
        ).to eq '<span class="text-green-700 dark:text-green-400"><strong class="font-medium">1</strong><small>.23</small>&nbsp;<small>&euro;</small></span>'
      end
    end

    context 'when negative' do
      let(:value) { -1.234 }

      it do
        expect(
          to_eur,
        ).to eq '<span class="text-red-700 dark:text-red-400"><strong class="font-medium">-1</strong><small>.23</small>&nbsp;<small>&euro;</small></span>'
      end
    end

    context 'with :max_precision option' do
      let(:value) { 10 }
      let(:options) { { max_precision: 2 } }

      it do
        expect(
          to_eur,
        ).to eq '<span class="text-green-700 dark:text-green-400"><strong class="font-medium">10</strong><small>.00</small>&nbsp;<small>&euro;</small></span>'
      end
    end

    context 'with :klass option' do
      let(:value) { 10 }
      let(:options) { { klass: 'foo' } }

      it do
        expect(
          to_eur,
        ).to eq '<span class="foo text-green-700 dark:text-green-400"><strong class="font-medium">10</strong>&nbsp;<small>&euro;</small></span>'
      end
    end
  end

  describe 'to_eur_per_kwh' do
    subject(:to_eur_per_kwh) { component.to_eur_per_kwh(**options) }

    let(:options) { {} }

    context 'when positive' do
      let(:value) { 0.2208 }

      it do
        expect(
          to_eur_per_kwh,
        ).to eq '<span class="text-green-700 dark:text-green-400"><strong class="font-medium">0</strong><small>.2208</small>&nbsp;<small>&euro;/kWh</small></span>'
      end
    end

    context 'when negative' do
      let(:value) { -0.2208 }

      it do
        expect(
          to_eur_per_kwh,
        ).to eq '<span class="text-red-700 dark:text-red-400"><strong class="font-medium">-0</strong><small>.2208</small>&nbsp;<small>&euro;/kWh</small></span>'
      end
    end

    context 'with :klass option' do
      let(:value) { 0.5 }
      let(:options) { { klass: 'foo' } }

      it do
        expect(
          to_eur_per_kwh,
        ).to eq '<span class="foo text-green-700 dark:text-green-400"><strong class="font-medium">0</strong><small>.5000</small>&nbsp;<small>&euro;/kWh</small></span>'
      end
    end
  end

  describe 'to_grad_celsius' do
    subject(:to_grad_celsius) { component.to_grad_celsius(**options) }

    let(:options) { {} }

    context 'when positive' do
      let(:value) { 1.234 }

      it do
        is_expected.to eq '<span><strong class="font-medium">1</strong><small>.2</small>&nbsp;<small>&deg;C</small></span>'
      end
    end

    context 'when negative' do
      let(:value) { -1.234 }

      it do
        is_expected.to eq '<span><strong class="font-medium">-1</strong><small>.2</small>&nbsp;<small>&deg;C</small></span>'
      end
    end

    context 'with :max_precision option' do
      let(:value) { 10 }
      let(:options) { { max_precision: 0 } }

      it do
        is_expected.to eq '<span><strong class="font-medium">10</strong>&nbsp;<small>&deg;C</small></span>'
      end
    end
  end

  describe 'to_weight' do
    subject(:to_weight) { component.to_weight(**options) }

    let(:options) { {} }

    context 'when small' do
      let(:value) { 5 } # 5 g

      it do
        is_expected.to eq '<span><strong class="font-medium">5</strong>&nbsp;<small>g</small></span>'
      end
    end

    context 'when medium' do
      let(:value) { 5234 } # ~ 5 kg

      it do
        is_expected.to eq '<span><strong class="font-medium">5</strong>&nbsp;<small>kg</small></span>'
      end
    end

    context 'when large' do
      let(:value) { 5_234_567 } # ~ 5,2 tons

      it do
        is_expected.to eq '<span><strong class="font-medium">5</strong><small>.2</small>&nbsp;<small>t</small></span>'
      end
    end
  end

  describe 'to_percent' do
    subject(:to_percent) { component.to_percent(**options) }

    let(:options) { {} }

    context 'when positive' do
      let(:value) { 12.345 }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-green-500 dark:text-green-400"><strong class="font-medium">12</strong><small>.3</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'when negative' do
      let(:value) { -12.345 }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-red-500 dark:text-red-400"><strong class="font-medium">-12</strong><small>.3</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'when zero' do
      let(:value) { 0 }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-red-500 dark:text-red-400"><strong class="font-medium">0</strong>&nbsp;<small>%</small></span>'
      end
    end

    context 'with sign option for positive value' do
      let(:value) { 12.345 }
      let(:options) { { sign: true } }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-green-500 dark:text-green-400"><strong class="font-medium">+12</strong><small>.3</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'with sign option for negative value' do
      let(:value) { -12.345 }
      let(:options) { { sign: true } }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-red-500 dark:text-red-400"><strong class="font-medium">-12</strong><small>.3</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'with max_precision option' do
      let(:value) { 12.3456789 }
      let(:options) { { max_precision: 3 } }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-green-500 dark:text-green-400"><strong class="font-medium">12</strong><small>.346</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'with precision option' do
      let(:value) { 12 }
      let(:options) { { precision: 2 } }

      it do
        expect(
          to_percent,
        ).to eq '<span class="text-green-500 dark:text-green-400"><strong class="font-medium">12</strong><small>.00</small>&nbsp;<small>%</small></span>'
      end
    end

    context 'with custom klass option' do
      let(:value) { 12.345 }
      let(:options) { { klass: 'custom-class' } }

      it do
        expect(
          to_percent,
        ).to eq '<span class="custom-class"><strong class="font-medium">12</strong><small>.3</small>&nbsp;<small>%</small></span>'
      end
    end
  end
end
