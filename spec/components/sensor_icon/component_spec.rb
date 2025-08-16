describe SensorIcon::Component, type: :component do
  subject(:component) { described_class.new(sensor, context:, **options) }

  let(:context) { nil }
  let(:options) { {} }

  describe 'basic sensor icons' do
    context 'when sensor is :inverter_power' do
      let(:sensor) { :inverter_power }

      it 'renders the correct icon class' do
        expect(component.call).to include('fa-sun')
      end
    end

    context 'when sensor is :house_power' do
      let(:sensor) { :house_power }

      it 'renders the correct icon class' do
        expect(component.call).to include('fa-home')
      end
    end

    context 'when sensor is :grid_import_power' do
      let(:sensor) { :grid_import_power }

      it 'renders the correct icon class' do
        expect(component.call).to include('fa-bolt')
      end
    end

    context 'when sensor is :wallbox_power' do
      let(:sensor) { :wallbox_power }

      it 'renders the correct icon class' do
        expect(component.call).to include('fa-car')
      end
    end

    context 'when sensor is :savings' do
      let(:sensor) { :savings }

      it 'renders the correct icon class' do
        expect(component.call).to include('fa-piggy-bank')
      end
    end
  end

  describe 'battery sensor icons with context' do
    let(:sensor) { :battery_soc }
    let(:context) { double('context', battery_soc:) }

    context 'when battery SOC is 5%' do
      let(:battery_soc) { 5 }

      it 'renders empty battery icon' do
        expect(component.call).to include('fa-battery-empty')
      end
    end

    context 'when battery SOC is 20%' do
      let(:battery_soc) { 20 }

      it 'renders quarter battery icon' do
        expect(component.call).to include('fa-battery-quarter')
      end
    end

    context 'when battery SOC is 40%' do
      let(:battery_soc) { 40 }

      it 'renders half battery icon' do
        expect(component.call).to include('fa-battery-half')
      end
    end

    context 'when battery SOC is 70%' do
      let(:battery_soc) { 70 }

      it 'renders three-quarters battery icon' do
        expect(component.call).to include('fa-battery-three-quarters')
      end
    end

    context 'when battery SOC is 90%' do
      let(:battery_soc) { 90 }

      it 'renders full battery icon' do
        expect(component.call).to include('fa-battery-full')
      end
    end

    context 'when no context is provided' do
      let(:context) { nil }

      it 'renders default battery icon' do
        expect(component.call).to include('fa-battery-half')
      end
    end
  end

  describe 'additional options' do
    let(:sensor) { :inverter_power }
    let(:options) { { class: 'additional-class', style: 'font-size: 200%;' } }

    it 'applies additional classes and styles' do
      result = component.call
      expect(result).to include('additional-class')
      expect(result).to include('font-size: 200%;')
      expect(result).to include('fa-sun')
    end
  end
end
