# A sensor declares two things about its value: `range:` says what the value
# may be, `calculate` says how it is derived. Sensor::Definitions::Dsl applies
# the first to the result of the second, so the bound is declared once and
# holds everywhere (the mechanism itself: dsl_spec.rb).
#
# Before that, every sensor whose arithmetic can leave its range carried the
# bound twice - once as `range:` and once as a [x, 0].max or .clamp(0, 100) at
# the end of its block. The duplicate is what a sensor can forget, and two of
# them did.
#
# These examples guard the guarantee at the sensors that depend on it. Each one
# gets inputs that are individually valid and whose bare arithmetic still lands
# outside the range: a subtrahend of 400 against a minuend of 100, or a share
# of 400 %.
describe 'the declared range' do # rubocop:disable RSpec/DescribeClass
  # A _pv half reports the SHARE of its base sensor that own solar covered, so
  # it cannot be negative. Its two inputs come from different writers, though,
  # and the grid half can briefly exceed the base it divides - noise the Power
  # Splitter wrote, not a measurement.
  #
  # house_power_pv and battery_charging_power_pv were the two that forgot the
  # bound. The raw InfluxDB path applies no clamp of its own, so they published
  # a negative solar share to every reader of that path, the MCP tools
  # get_series and get_totals below one day among them.
  #
  # The rule belongs to the family, not to a single sensor, so it is pinned for
  # every member at once - a new _pv sibling inherits it and cannot forget it.
  describe 'across the power split family' do
    # Every member with a base/grid pair. custom_power_total_pv sums its inputs
    # instead and takes as many as there are consumers, so it has no pair to
    # oversubtract from.
    def pv_sensors
      Sensor::Registry
        .by_category(:power_splitter)
        .select { it.name.to_s.end_with?('_pv') && it.dependencies.size == 2 }
    end

    def oversubtracted(sensor)
      base, grid = sensor.dependencies

      sensor.calculate(base => 100.0, grid => 400.0)
    end

    it 'covers every sensor of the family' do
      expect(pv_sensors.map(&:name)).to include(
        :house_power_pv,
        :battery_charging_power_pv,
        :heatpump_power_pv,
        :wallbox_power_pv,
      )
    end

    it 'rules a negative share out by declaration' do
      expect(pv_sensors.map(&:value_range)).to all(eq(0..))
    end

    it 'floors the share at zero when the grid half exceeds the base sensor' do
      results = pv_sensors.to_h { [it.name, oversubtracted(it)] }

      expect(results.reject { |_name, value| value.zero? }).to be_empty
    end

    it 'leaves an ordinary split untouched' do
      sensor = Sensor::Registry[:house_power_pv]

      expect(sensor.calculate(house_power: 1_000.0, house_power_grid: 400.0)).to eq(600.0)
    end
  end

  # The sensors outside the split family that used to write their bound by
  # hand: a difference whose subtrahend overtakes its minuend, or a share whose
  # denominator collapses.
  describe 'at the sensors that dropped their own bound' do
    {
      self_consumption: {
        inverter_power: 100.0,
        grid_export_power: 400.0,
      },
      heatpump_power_env: {
        heatpump_heating_power: 100.0,
        heatpump_power: 400.0,
      },
      house_power_without_custom: {
        house_power: 100.0,
        custom_power_total: 400.0,
      },
      autarky: {
        total_consumption: 100.0,
        grid_import_power: 400.0,
      },
    }.each do |name, inputs|
      it "floors #{name} at 0" do
        expect(Sensor::Registry[name].calculate(**inputs)).to eq(0)
      end
    end

    {
      grid_quote: {
        total_consumption: 100.0,
        grid_import_power: 400.0,
        inverter_power: 0.0,
      },
      self_consumption_quote: {
        self_consumption: 400.0,
        inverter_power: 100.0,
      },
    }.each do |name, inputs|
      it "caps #{name} at 100" do
        expect(Sensor::Registry[name].calculate(**inputs)).to eq(100)
      end
    end

    # The bound must not swallow a valid result on its way.
    it 'leaves a value inside the range untouched' do
      expect(
        Sensor::Registry[:self_consumption].calculate(
          inverter_power: 1_000.0,
          grid_export_power: 400.0,
        ),
      ).to eq(600.0)
    end
  end
end
