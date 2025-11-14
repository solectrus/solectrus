describe Forecast::Component do
  subject(:component) { described_class.new }

  let(:outdoor_temp_exists) { true }

  before do
    allow(Sensor::Config).to receive(:exists?).with(
      :outdoor_temp_forecast,
    ).and_return(outdoor_temp_exists)
  end

  describe '#show_outdoor_temp?' do
    context 'when outdoor_temp_forecast sensor exists' do
      let(:outdoor_temp_exists) { true }

      it 'returns true' do
        expect(component.show_outdoor_temp?).to be(true)
      end
    end

    context 'when outdoor_temp_forecast sensor does not exist' do
      let(:outdoor_temp_exists) { false }

      it 'returns false' do
        expect(component.show_outdoor_temp?).to be(false)
      end
    end
  end
end
