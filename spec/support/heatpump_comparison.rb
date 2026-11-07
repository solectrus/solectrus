# The data of the comparison of the heat pump with a fossil heating: the
# fuel prices in InfluxDB (`prices`, { fuel type => [[date, price], ...] })
# and a day with heat
RSpec.shared_context 'with heat pump comparison' do
  let(:prices) { {} }

  # 9 kWh of heat from 3 kWh, 1 kWh of them from the grid
  def heat_day(date)
    create_summary(date:, values: [[:heatpump_heating_power, :sum, 9_000], [:heatpump_power, :sum, 3_000], [:heatpump_power_grid, :sum, 1_000]])
  end

  before do
    allow(Sensor::Query::FuelPrices).to receive(:new) do |fuel_type|
      instance_double(Sensor::Query::FuelPrices, call: prices.fetch(fuel_type, []))
    end
  end
end
