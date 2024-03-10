describe EssentialsTile::Component, type: :component do
  subject(:component) { described_class.new calculator:, field:, timeframe: }

  context "when year's savings" do
    let(:calculator) { double(Calculator::Range, savings: 500) }

    let(:field) { :savings }
    let(:timeframe) { Timeframe.year }

    it 'returns the correct value' do
      expect(component.value).to eq 500
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 1.hour
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-piggy-bank'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :blue
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-blue-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-blue-100'
    end
  end

  context "when day's inverter_power" do
    let(:calculator) { double(Calculator::Range, inverter_power: 20_000) }

    let(:field) { :inverter_power }
    let(:timeframe) { Timeframe.day }

    it 'returns the correct value' do
      expect(component.value).to eq 20_000
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 1.minute
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-sun'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :green
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-green-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-green-100'
    end
  end

  context 'when current inverter_power (present)' do
    let(:calculator) { double(Calculator::Range, inverter_power: 1_800) }

    let(:field) { :inverter_power }
    let(:timeframe) { Timeframe.now }

    it 'returns the correct value' do
      expect(component.value).to eq 1_800
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 5.seconds
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-sun'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :green
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-green-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-green-100'
    end
  end

  context 'when current inverter_power (blank)' do
    let(:calculator) { double(Calculator::Range, inverter_power: nil) }

    let(:field) { :inverter_power }
    let(:timeframe) { Timeframe.now }

    it 'returns the correct value' do
      expect(component.value).to be_nil
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 5.seconds
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-sun'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :gray
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-gray-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-gray-100'
    end
  end

  context "when this week's house power" do
    let(:calculator) { double(Calculator::Range, house_power: 100) }

    let(:field) { :house_power }
    let(:timeframe) { Timeframe.week }

    it 'returns the correct value' do
      expect(component.value).to eq 100
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 5.minutes
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-home'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :gray
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-gray-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-gray-100'
    end
  end

  context 'when overall bat_fuel_charge' do
    let(:calculator) { double(Calculator::Range, bat_fuel_charge: 50) }

    let(:field) { :bat_fuel_charge }
    let(:timeframe) { Timeframe.all }

    it 'returns the correct value' do
      expect(component.value).to eq 50
    end

    it 'returns the correct refresh_interval' do
      expect(component.refresh_interval).to eq 1.day
    end

    it 'returns the correct icon_class' do
      expect(component.icon_class).to eq 'fa-battery-half'
    end

    it 'returns the correct color' do
      expect(component.color).to eq :green
    end

    it 'returns the correct background color' do
      expect(component.background_color).to eq 'bg-green-600'
    end

    it 'returns the correct text primary color' do
      expect(component.text_primary_color).to eq 'text-white'
    end

    it 'returns the correct text secondary color' do
      expect(component.text_secondary_color).to eq 'text-green-100'
    end
  end
end
