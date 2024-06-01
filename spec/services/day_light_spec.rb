describe DayLight do
  subject(:day_light) { described_class.new(date) }

  let(:date) { Date.new(2023, 3, 4) }

  before do
    influx_batch do
      {
        # Before sunrise
        Time.new(date.year, date.month, date.day, 1, 0, 0, '+01:00') => 0,
        # Sunrise
        Time.new(date.year, date.month, date.day, 7, 10, 0, '+01:00') => 100,
        # High noon
        Time.new(date.year, date.month, date.day, 12, 0, 0, '+01:00') => 5000,
        # Sunset
        Time.new(date.year, date.month, date.day, 18, 21, 0, '+01:00') => 50,
        # After sunset
        Time.new(date.year, date.month, date.day, 22, 0, 0, '+01:00') => 0,
      }.each_pair do |time, value|
        add_influx_point name: measurement_inverter_power_forecast,
                         fields: {
                           field_inverter_power_forecast => value,
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
