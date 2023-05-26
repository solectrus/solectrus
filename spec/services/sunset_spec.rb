describe Sunset do
  subject(:sunset) { described_class.new(date) }

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
        add_influx_point name:
                           Rails.configuration.x.influx.measurement_forecast,
                         fields: {
                           watt: rand(1000),
                         },
                         time:
      end
    end
  end

  describe '#time' do
    subject { sunset.time }

    it do
      is_expected.to eq(
        Time.new(date.year, date.month, date.day, 18, 21, 0, '+01:00'),
      )
    end
  end
end
