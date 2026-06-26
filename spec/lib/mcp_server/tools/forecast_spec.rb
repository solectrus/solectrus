describe McpServer::Tools::Forecast do
  let(:now) { Time.zone.local(2030, 6, 15, 12, 30) }
  let(:today) { now.to_date }

  before { travel_to(now) }

  def call(**args)
    response = described_class.call(**args)
    [response.error?, response.content.first[:text]]
  end

  def forecast(**args)
    _error, text = call(**args)
    JSON.parse(text, symbolize_names: true)
  end

  # Generation forecast: 0 W at night, `watt` between 06:00 and 20:00.
  def seed_generation(date, watt: 800.0)
    influx_batch do
      96.times do |i|
        time = date.in_time_zone.beginning_of_day + (i * 15).minutes
        value = (6...20).cover?(time.hour) ? watt : 0.0
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast),
          fields: {
            watt: value,
          },
          time:,
        )
      end
    end
  end

  # Temperature forecast: 10 in the morning, 20 in the afternoon (Celsius).
  def seed_temperature(date)
    influx_batch do
      96.times do |i|
        time = date.in_time_zone.beginning_of_day + (i * 15).minutes
        add_influx_point(
          name: Sensor::Config.measurement(:outdoor_temp_forecast),
          fields: {
            temp: time.hour < 12 ? 10.0 : 20.0,
          },
          time:,
        )
      end
    end
  end

  describe '.call generation' do
    context 'with forecast data' do
      before do
        seed_generation(today)
        seed_generation(today + 1)
        seed_generation(today + 2)
      end

      it 'reports Wh, the timezone and the remaining energy for today' do
        data = forecast

        expect(data[:timezone]).to eq(Time.zone.name)
        expect(data[:generation][:unit]).to eq('Wh')
        expect(data[:generation][:today_remaining]).to be > 0
      end

      it 'lists the expected energy per upcoming day, excluding today' do
        days = forecast[:generation][:days]

        expect(days.pluck(:date)).to eq([(today + 1).iso8601, (today + 2).iso8601])
        expect(days.pluck(:expected)).to all(be > 0)
      end

      it 'counts only the remaining part of today (no double counting)' do
        data = forecast[:generation]
        full_next_day = data[:days].first[:expected]

        expect(data[:today_remaining]).to be < full_next_day
      end
    end

    context 'when an upcoming day lacks data' do
      before { seed_generation(today + 1) } # today + 2 is absent

      it 'omits the day without forecast data' do
        expect(forecast[:generation][:days].pluck(:date)).to eq([(today + 1).iso8601])
      end
    end

    context 'without forecast data' do
      it 'reports nothing expected' do
        data = forecast[:generation]

        expect(data[:today_remaining]).to eq(0)
        expect(data[:days]).to be_empty
      end
    end

    context 'with an unconfigured generation forecast sensor' do
      it 'returns an error' do
        allow(Sensor::Config).to receive(:exists?).and_call_original
        allow(Sensor::Config).to receive(:exists?).with(
          :inverter_power_forecast,
        ).and_return(false)

        error, text = call

        expect(error).to be(true)
        expect(text).to include('not configured')
      end
    end
  end

  describe '.call temperature' do
    before { seed_generation(today) } # generation sensor must exist

    context 'with a temperature forecast' do
      before do
        seed_temperature(today)
        seed_temperature(today + 1)
      end

      it 'returns daily min/max/avg in °C for today and the upcoming days' do
        temperature = forecast[:temperature]

        expect(temperature[:unit]).to eq('°C')
        expect(temperature[:days].pluck(:date)).to eq(
          [today.iso8601, (today + 1).iso8601],
        )

        day = temperature[:days].first
        expect(day[:min]).to eq(10.0)
        expect(day[:max]).to eq(20.0)
        expect(day[:avg]).to be_between(10.0, 20.0)
      end
    end

    context 'without a temperature forecast configured' do
      before do
        allow(Sensor::Config).to receive(:exists?).and_call_original
        allow(Sensor::Config).to receive(:exists?).with(
          :outdoor_temp_forecast,
        ).and_return(false)
      end

      it 'omits the temperature section' do
        expect(forecast).not_to have_key(:temperature)
      end
    end
  end
end
