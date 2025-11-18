describe ForecastComment::Component, type: :component do
  subject(:component) do
    described_class.new data:, sensor_name: :inverter_power, timeframe:
  end

  let(:timeframe) { Timeframe.new(date) }
  let(:sunset) { nil }

  let(:data) { double(forecast_deviation:, inverter_power_forecast: 1000) }

  before do
    allow(Sensor::Query::DayLight).to receive(:new).and_return(sunset)

    render_inline(component)
  end

  context 'when timeframe is in the past' do
    let(:date) { Date.yesterday.to_s }

    context 'when deviation is zero' do
      let(:forecast_deviation) { 0 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.exactly')
      end

      it 'has no tooltip-content' do
        expect(page.native.inner_html).not_to include('<template')
      end
    end

    context 'when deviation is positive' do
      let(:forecast_deviation) { 10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t(
                    'forecast.better_html',
                    percent: '10 %',
                  )
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is negative' do
      let(:forecast_deviation) { -10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.worse_html', percent: '10 %')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end
  end

  context 'when timeframe is current day, before sunset' do
    let(:date) { Date.current.to_s }
    let(:sunset) { instance_double(Sensor::Query::DayLight, sunset: 5.minutes.since) }

    context 'when deviation is zero' do
      let(:forecast_deviation) { 0 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.expect_html', value: '1 kWh')
      end

      it 'has no tooltip-content' do
        expect(page).to have_no_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is positive' do
      let(:forecast_deviation) { 10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t(
                    'forecast.better_html',
                    percent: '10 %',
                  )
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is negative' do
      let(:forecast_deviation) { -10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.expect_html', value: '1 kWh')
      end

      it 'has no tooltip-content' do
        expect(page.native.inner_html).not_to include('<template')
      end
    end
  end

  context 'when timeframe is current day, after sunset' do
    let(:date) { Date.current.to_s }
    let(:sunset) { instance_double(Sensor::Query::DayLight, sunset: 5.minutes.ago) }

    context 'when deviation is zero' do
      let(:forecast_deviation) { 0 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.exactly')
      end

      it 'has no tooltip-content' do
        expect(page.native.inner_html).not_to include('<template')
      end
    end

    context 'when deviation is positive' do
      let(:forecast_deviation) { 10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t(
                    'forecast.better_html',
                    percent: '10 %',
                  )
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end

    context 'when deviation is negative' do
      let(:forecast_deviation) { -10 }

      it 'comments correctly' do
        expect(page).to have_text I18n.t('forecast.worse_html', percent: '10 %')
      end

      it 'has tooltip-content' do
        expect(page).to have_css('div', id: 'forecast-expectation')
      end
    end
  end
end
