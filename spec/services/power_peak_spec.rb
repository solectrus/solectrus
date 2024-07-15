describe PowerPeak do
  let(:peak) do
    described_class.new(sensors: %i[inverter_power house_power wallbox_power])
  end

  let(:beginning) { 3.months.ago.beginning_of_month }

  before do
    influx_batch do
      3.times do |index|
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => (index + 1) * 1000,
                           field_house_power => 500,
                           field_wallbox_power => (index + 1) * 3000,
                         },
                         time: (beginning + index.month)
      end
    end
  end

  describe '#call' do
    subject { peak.call(start: beginning) }

    it do
      is_expected.to eq(
        { inverter_power: 3_000, house_power: 500, wallbox_power: 9_000 },
      )
    end
  end
end
