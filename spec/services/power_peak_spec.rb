describe PowerPeak do
  let(:measurement) { "Test#{described_class}" }

  let(:peak) do
    described_class.new(
      fields: %w[inverter_power house_power wallbox_charge_power],
      measurements: [measurement],
    )
  end

  let(:beginning) { 3.months.ago.beginning_of_month }

  before do
    3.times do |index|
      add_influx_point name: measurement,
                       fields: {
                         inverter_power: (index + 1) * 1000,
                         house_power: 500,
                         wallbox_charge_power: (index + 1) * 3000,
                       },
                       time: (beginning + index.month)
    end
  end

  describe '#result' do
    subject { peak.result(start: beginning) }

    it do
      is_expected.to eq(
        {
          'inverter_power' => 3_000,
          'house_power' => 500,
          'wallbox_charge_power' => 9_000,
        },
      )
    end
  end
end
