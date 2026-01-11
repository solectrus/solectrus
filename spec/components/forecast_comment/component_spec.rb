describe ForecastComment::Component, type: :component do
  subject(:component) do
    described_class.new data:, sensor_name: :inverter_power, timeframe:
  end

  let(:timeframe) { Timeframe.new(date) }
  let(:sunset) { nil }

  let(:data) do
    double(
      forecast_deviation:,
      inverter_power_forecast: 10_000,
      inverter_power: forecast_deviation.to_i + 10_000,
    )
  end

  before do
    allow(Sensor::Query::DayLight).to receive(:new).and_return(sunset)

    render_inline(component)
  end

  context 'when timeframe is in the past' do
    let(:date) { Date.yesterday.to_s }

    context 'when deviation is within threshold (< 500 Wh)' do
      let(:forecast_deviation) { 400 }

      it 'shows approximately as expected' do
        expect(page).to have_text I18n.t('forecast.approximately')
      end

      it 'has no tooltip-content' do
        expect(page.native.inner_html).not_to include('forecast-expectation')
      end
    end

    context 'when deviation is significantly positive (> 500 Wh)' do
      let(:forecast_deviation) { 1000 }

      it 'shows absolute value more than expected' do
        expect(page).to have_text I18n.t('forecast.better_html', value: '1 kWh')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is significantly negative (< -500 Wh)' do
      let(:forecast_deviation) { -1000 }

      it 'shows absolute value less than expected' do
        expect(page).to have_text I18n.t('forecast.worse_html', value: '1 kWh')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when forecast was zero but actual generation occurred' do
      let(:forecast_deviation) { 900 }

      let(:data) do
        double(
          forecast_deviation: 900,
          inverter_power_forecast: 0,
          inverter_power: 900,
        )
      end

      it 'shows absolute value in kWh' do
        expect(page).to have_text I18n.t('forecast.better_html', value: '1 kWh')
      end
    end
  end

  context 'when timeframe is current day, before sunset' do
    let(:date) { Date.current.to_s }
    let(:sunset) { instance_double(Sensor::Query::DayLight, sunset: 5.minutes.since) }

    context 'when deviation exists' do
      let(:forecast_deviation) { 1000 }

      it 'shows expected value (not deviation)' do
        expect(page).to have_text I18n.t('forecast.expect_html', value: '10 kWh')
      end

      it 'has no tooltip-content' do
        expect(page).to have_no_css('div', id: 'forecast-expectation')
      end
    end
  end

  context 'when timeframe is current day, after sunset' do
    let(:date) { Date.current.to_s }
    let(:sunset) { instance_double(Sensor::Query::DayLight, sunset: 5.minutes.ago) }

    context 'when deviation is within threshold' do
      let(:forecast_deviation) { 200 }

      it 'shows approximately as expected' do
        expect(page).to have_text I18n.t('forecast.approximately')
      end

      it 'has no tooltip-content' do
        expect(page.native.inner_html).not_to include('forecast-expectation')
      end
    end

    context 'when deviation is significantly positive' do
      let(:forecast_deviation) { 2000 }

      it 'shows absolute value more than expected' do
        expect(page).to have_text I18n.t('forecast.better_html', value: '2 kWh')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is significantly negative' do
      let(:forecast_deviation) { -2000 }

      it 'shows absolute value less than expected' do
        expect(page).to have_text I18n.t('forecast.worse_html', value: '2 kWh')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end
  end
end
