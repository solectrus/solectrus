describe DayLight do
  subject(:day_light) { described_class.new(date) }

  let(:date) { Date.new(2023, 3, 4) }

  before do
    influx_batch do
      [
        # Sunrise
        Time.new(date.year, date.month, date.day, 7, 10, 0, '+01:00'),
        # Somtime during the day
        Time.new(date.year, date.month, date.day, 9, 30, 0, '+01:00'),
        # Sunset
        Time.new(date.year, date.month, date.day, 18, 21, 0, '+01:00'),
      ].each do |time|
        add_influx_point name: measurement_inverter_power_forecast,
                         fields: {
                           field_inverter_power_forecast => rand(1000),
                         },
                         time:
      end
    end
  end

  describe '#sunrise' do
    subject { day_light.sunrise }

    it do
      is_expected.to eq(
        Time.new(date.year, date.month, date.day, 7, 10, 0, '+01:00'),
      )
    end
  end

  describe '#sunset' do
    subject { day_light.sunset }

    it do
      is_expected.to eq(
        Time.new(date.year, date.month, date.day, 18, 21, 0, '+01:00'),
      )
    end
  end
end
