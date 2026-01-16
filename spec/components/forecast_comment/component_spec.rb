describe ForecastComment::Component, type: :component do
  subject(:component) do
    described_class.new(
      data: double(
        forecast_deviation:,
        inverter_power_forecast:,
        inverter_power: forecast_deviation.to_i + inverter_power_forecast,
      ),
      sensor_name: :inverter_power,
      timeframe: Timeframe.new(date),
      chart:,
    )
  end

  let(:chart) { nil }
  let(:date) { Date.yesterday.to_s }
  let(:day_light) { nil }
  let(:forecast_deviation) { 0 }
  let(:inverter_power_forecast) { 10_000 }

  before do
    allow(Sensor::Query::DayLight).to receive(:new).and_return(day_light)
    render_inline(component)
  end

  describe 'past timeframe' do
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
      let(:inverter_power_forecast) { 0 }

      it 'shows absolute value in kWh' do
        expect(page).to have_text I18n.t('forecast.better_html', value: '1 kWh')
      end
    end
  end

  describe 'current day before sunrise' do
    let(:date) { Date.current.to_s }
    let(:forecast_deviation) { 0 }
    let(:day_light) do
      instance_double(
        Sensor::Query::DayLight,
        sunrise: 1.hour.from_now,
        sunset: 10.hours.from_now,
      )
    end

    context 'when chart provides remaining_forecast_wh' do
      let(:chart) { instance_double(Sensor::Chart::InverterPower, remaining_forecast_wh: 10_000) }

      it 'shows forecast without "still" (no production yet)' do
        expect(page).to have_text I18n.t(
          'forecast.expect_html',
          value: '10 kWh',
        )
      end
    end
  end

  describe 'current day after sunrise, before sunset' do
    let(:date) { Date.current.to_s }
    let(:forecast_deviation) { 1000 }
    let(:day_light) do
      instance_double(
        Sensor::Query::DayLight,
        sunrise: 2.hours.ago,
        sunset: 2.hours.from_now,
      )
    end

    context 'when chart provides remaining_forecast_wh' do
      let(:chart) { instance_double(Sensor::Chart::InverterPower, remaining_forecast_wh: 5000) }

      it 'shows remaining forecast value with "still expected" text' do
        expect(page).to have_text I18n.t(
          'forecast.expect_remaining_html',
          value: '5 kWh',
        )
      end

      it 'has no tooltip-content' do
        expect(page).to have_no_css('div', id: 'forecast-expectation')
      end
    end

    context 'when chart does not provide remaining_forecast_wh' do
      it 'falls back to full day forecast display' do
        expect(page).to have_text I18n.t(
          'forecast.expect_html',
          value: '10 kWh',
        )
      end
    end
  end

  describe 'current day after sunset' do
    let(:date) { Date.current.to_s }
    let(:day_light) do
      instance_double(
        Sensor::Query::DayLight,
        sunrise: 10.hours.ago,
        sunset: 5.minutes.ago,
      )
    end

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
