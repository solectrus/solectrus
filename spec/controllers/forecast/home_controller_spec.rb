describe Forecast::HomeController do
  let(:controller) { described_class.new }

  describe '#days' do
    let(:availability_query) do
      instance_double(Sensor::Query::ForecastAvailability)
    end

    before do
      allow(Sensor::Query::ForecastAvailability).to receive(:new).with(
        :inverter_power_forecast,
        :outdoor_temp_forecast,
      ).and_return(availability_query)
    end

    context 'when no forecast data is available' do
      before { allow(availability_query).to receive(:call).and_return(nil) }

      it 'returns nil' do
        expect(controller.__send__(:days)).to be_nil
      end
    end

    context 'when forecast data is available for 5 days' do
      before do
        allow(availability_query).to receive(:call).and_return(
          Date.current + 4.days,
        )
      end

      it 'returns 5 days' do
        expect(controller.__send__(:days)).to eq(5)
      end
    end

    context 'when forecast data is available for today only' do
      before do
        allow(availability_query).to receive(:call).and_return(Date.current)
      end

      it 'returns 2 days (clamped minimum)' do
        expect(controller.__send__(:days)).to eq(2)
      end
    end
  end

  describe '#timeframe' do
    context 'when days is 2' do
      before { allow(controller).to receive(:days).and_return(2) }

      it 'creates timeframe from today to tomorrow' do
        timeframe = controller.__send__(:timeframe)
        expect(timeframe.beginning).to eq(Date.current.beginning_of_day)
        expect(timeframe.ending).to eq(Date.tomorrow.end_of_day)
      end
    end

    context 'when days is 7' do
      before { allow(controller).to receive(:days).and_return(7) }

      it 'creates timeframe from today to 6 days from now' do
        timeframe = controller.__send__(:timeframe)
        expect(timeframe.beginning).to eq(Date.current.beginning_of_day)
        expect(timeframe.ending).to eq((Date.current + 6.days).end_of_day)
      end
    end
  end
end
