# Measures the serialized size of every MCP tool response against one fixed,
# deterministic scenario.
#
# The MCP server's consumer is a language model, not a chart client, so every
# byte is paid twice: once in the model's context window and once in latency.
# Keeping the measurement inside the suite is what makes a future regression
# fail loudly instead of merely being plausible.
#
# The subject is the serialized output of all tools together, not one class.
describe 'MCP payload size' do # rubocop:disable RSpec/DescribeClass
  # A fixed instant, so bucket grids, timeframes and the seeded values line up
  # identically on every run - byte counts are only comparable if the scenario
  # is.
  def now = Time.zone.local(2024, 6, 15, 12, 0, 0)

  def series_day = Date.new(2024, 6, 14)

  def summary_days = 120

  # The sensors of the get_series benchmarks. All measured (not derived), so
  # the seeded Influx points reach them unchanged.
  def series_sensors
    %w[house_power grid_import_power grid_export_power battery_soc heatpump_power]
  end

  # A cross-section for get_totals: energies, percentages, money, CO2, a
  # temperature and a unitless ratio - one sensor per unit whose precision the
  # response has to commit to.
  def totals_sensors
    %w[
      inverter_power
      house_power
      grid_import_power
      grid_export_power
      autarky
      self_consumption_quote
      grid_quote
      savings
      total_costs
      co2_reduction
      outdoor_temp
      heatpump_cop
    ]
  end

  def ranking_sensors = %w[inverter_power house_power grid_import_power]

  # Upper bound per call, in bytes. Not a measurement but a contract: a change
  # that pushes a response past its ceiling has to be seen and the ceiling
  # moved deliberately. Set ~15 % above the sizes currently measured, so
  # ordinary noise does not trip them but a lost improvement does.
  def ceilings
    {
      'tool definitions + instructions' => 24_400,
      'get_current_values (all sensors)' => 13_500,
      'list_sensors' => 17_000,
      'get_sensor_details (3 sensors)' => 1_000,
      'get_system_info' => 400,
      'get_prices' => 1_900,
      'get_totals (12 sensors, month)' => 1_500,
      'get_series (1 sensor, day, 1h)' => 1_600,
      'get_series (5 sensors, day, 1m)' => 8_000,
      'get_ranking (3 sensors, all, day)' => 1_700,
      'get_forecast' => 1_350,
      'get_amortization' => 2_100,
    }
  end

  # Values are deliberately irrational-looking: a benchmark seeded with round
  # numbers would hide exactly the float noise this measurement is about.
  def noisy(base, index)
    base * ((Math.sin(index) / 3.0) + 1)
  end

  def measurement_and_field(sensor_name)
    name = sensor_name.to_sym
    [Sensor::Config.measurement(name), Sensor::Config.field(name)]
  end

  # One point per configured raw sensor, timestamped just before `now` so it is
  # inside every sensor's max_age and get_current_values reports a live value.
  def seed_live_values
    influx_batch do
      Sensor::Config.sensors.reject(&:calculated?).each_with_index do |sensor, index|
        next if sensor.forecast?

        name, field = measurement_and_field(sensor.name)
        next unless name && field

        add_influx_point(name:, fields: { field => live_value(sensor, index) }, time: now - 30.seconds)
      end
    end
  end

  def live_value(sensor, index)
    case sensor.unit
    when :percent then noisy(60, index).clamp(0, 100)
    when :celsius then noisy(12, index)
    when :boolean then index.even?
    when :string then 'ok'
    else noisy(800, index)
    end
  end

  # A full day of 1-minute samples for the series sensors, so a fine-grained
  # request measures the cost of values rather than the cost of nulls.
  def seed_series_day
    influx_batch do
      series_sensors.each_with_index do |sensor_name, sensor_index|
        name, field = measurement_and_field(sensor_name)

        1440.times do |minute|
          add_influx_point(
            name:,
            fields: {
              field => noisy((sensor_index * 100) + 700, minute),
            },
            time: series_day.beginning_of_day + minute.minutes,
          )
        end
      end
    end
  end

  # The horizon get_forecast scans, in days. Seeding the whole of it - rather
  # than the few days a fixture would casually cover - is what makes the
  # measurement the tool's own upper bound instead of the fixture's.
  def forecast_horizon_days = 10

  # 15-minute forecast samples across the full horizon. 96 per day, so every
  # day clears the >= 2 samples over >= 8 h that Day#valid? demands and none
  # is dropped as a partial day.
  def seed_forecast
    influx_batch do
      (0..((forecast_horizon_days + 1) * 96)).each do |step|
        time = now.beginning_of_day + (step * 15).minutes

        add_forecast_point(:inverter_power_forecast, generation_value(time, step), time)
        add_forecast_point(:outdoor_temp_forecast, noisy(14, step), time)
      end
    end
  end

  def add_forecast_point(sensor_name, value, time)
    name, field = measurement_and_field(sensor_name)
    add_influx_point(name:, fields: { field => value }, time:)
  end

  # A diurnal bell, zero outside daylight. Not cosmetic: Sensor::Forecast::Day
  # counts a day as complete only when its first sample is near zero, so a flat
  # round-the-clock curve - 2.5 kW at 3 a.m. - yields no generation days at
  # all, and the ceiling ends up measuring the temperature section alone.
  def generation_value(time, step)
    daylight = Math.sin((time.hour + (time.min / 60.0) - 5) / 16.0 * Math::PI)
    return 0.0 if daylight <= 0

    noisy(daylight * 2500, step)
  end

  # get_prices caps its history at `limit` (10 by default), so seeding MORE
  # than the cap is what pins the measurement to the tool's own bound: the
  # response then measures the largest a default call can ever be, and stays
  # there no matter how much history an instance accumulates.
  def seed_prices
    Price.names.each_key do |price_name|
      12.times do |index|
        Price.create!(
          name: price_name,
          starts_at: Date.new(2021, 7, 1) + (index * 3).months,
          value: noisy(price_name == 'electricity' ? 0.30 : 0.08, index).round(5),
          note: "Tariff adjustment #{index + 1}",
        )
      end
    end
  end

  # Daily summaries backing get_totals (month) and get_ranking (all).
  def seed_summaries
    summary_days.times do |offset|
      create_summary(date: series_day - offset, values: summary_values(offset))
    end
  end

  def summary_values(index)
    [
      [:inverter_power, :sum, noisy(28_000, index)],
      [:inverter_power, :max, noisy(7_000, index)],
      [:house_power, :sum, noisy(11_000, index)],
      [:grid_import_power, :sum, noisy(6_000, index)],
      [:grid_export_power, :sum, noisy(9_000, index)],
      [:heatpump_power, :sum, noisy(4_000, index)],
      [:heatpump_heating_power, :sum, noisy(12_000, index)],
      [:wallbox_power, :sum, noisy(3_000, index)],
      [:battery_charging_power, :sum, noisy(5_000, index)],
      [:battery_discharging_power, :sum, noisy(4_500, index)],
      [:battery_soc, :avg, noisy(55, index).clamp(0, 100)],
      [:outdoor_temp, :avg, noisy(9, index)],
    ]
  end

  def seed_cash_flows
    CashFlow.create!(date: Date.new(2020, 11, 27), amount: -24_500, category: 'investment', note: 'PV system')
    CashFlow.create!(date: Date.new(2021, 3, 1), amount: 2_000, category: 'subsidy', note: 'Grant')
    CashFlow.create!(date: Date.new(2022, 5, 1), amount: -180.55, category: 'operating_cost', note: 'Insurance')
    CashFlow.create!(date: Date.new(2023, 9, 1), amount: 420.75, category: 'compensation', note: 'Feed-in')
  end

  def payload(tool, **args)
    response = tool.call(server_context: nil, **args)
    if response.error?
      raise ArgumentError, "#{tool.tool_name} failed: #{response.content.first[:text]}"
    end

    response.content.first[:text]
  end

  # Every tool's name, description, input schema and annotations, as the client
  # receives them in `tools/list`. Not a response but the entry fee: it is sent
  # before a single measurement is read, so it belongs in the same benchmark.
  def tool_definitions
    server = McpServer::Server.build
    definitions = server.tools.values.map { it.to_h.to_json }

    (definitions + [server.instructions.to_s]).join
  end

  # The benchmark set: the calls a model realistically makes in one session.
  def benchmarks
    {
      'tool definitions + instructions' => -> { tool_definitions },
      'get_current_values (all sensors)' => -> { payload(McpServer::Tools::CurrentValues) },
      'list_sensors' => -> { payload(McpServer::Tools::ListSensors) },
      'get_sensor_details (3 sensors)' => lambda {
        payload(McpServer::Tools::SensorDetails, sensors: %w[house_power savings battery_soc])
      },
      'get_system_info' => -> { payload(McpServer::Tools::SystemInfo) },
      'get_prices' => -> { payload(McpServer::Tools::Prices) },
      'get_totals (12 sensors, month)' => lambda {
        payload(McpServer::Tools::Totals, timeframe: 'month', sensors: totals_sensors)
      },
      'get_series (1 sensor, day, 1h)' => lambda {
        payload(
          McpServer::Tools::Series,
          sensors: [series_sensors.first],
          timeframe: series_day.to_s,
          resolution: '1h',
        )
      },
      'get_series (5 sensors, day, 1m)' => lambda {
        payload(McpServer::Tools::Series, sensors: series_sensors, timeframe: series_day.to_s, resolution: '1m')
      },
      'get_ranking (3 sensors, all, day)' => lambda {
        payload(McpServer::Tools::Ranking, sensors: ranking_sensors, timeframe: 'all')
      },
      'get_forecast' => -> { payload(McpServer::Tools::Forecast) },
      'get_amortization' => -> { payload(McpServer::Tools::Amortization) },
    }
  end

  before do
    travel_to now
    Summary.delete_all
    Price.delete_all
    seed_summaries
    seed_cash_flows
    seed_prices
    seed_live_values
    seed_series_day
    seed_forecast
  end

  it 'keeps every benchmark call within its size ceiling' do
    oversized =
      benchmarks.filter_map do |label, call|
        bytes = call.call.bytesize
        ceiling = ceilings[label]

        "#{label}: #{bytes} bytes, ceiling #{ceiling}" if bytes > ceiling
      end

    expect(oversized).to be_empty, -> { "Over the size ceiling:\n#{oversized.join("\n")}" }
  end

  # A ceiling only guards what the scenario actually reaches. get_prices and
  # get_forecast grow with the data behind them, and both were once seeded so
  # thinly that their ceilings sat below what a real instance already returns -
  # a guard that could not have caught anything. So the scenario has to be
  # pinned at each tool's own bound, not merely at "some data present".
  it 'drives the size-dependent responses to their upper bound' do
    prices = JSON.parse(payload(McpServer::Tools::Prices), symbolize_names: true)
    forecast = JSON.parse(payload(McpServer::Tools::Forecast), symbolize_names: true)

    # The history is capped by `limit`, so saturating it is the largest a
    # default call can be, however long an instance keeps changing tariffs.
    expect(prices[:prices].map { _1[:history].size }).to all(eq(prices[:limit]))

    # Generation counts the days AFTER today, temperature includes today.
    expect(forecast[:generation][:days].size).to eq(forecast_horizon_days)
    expect(forecast[:temperature][:days].size).to eq(forecast_horizon_days + 1)
  end
end
