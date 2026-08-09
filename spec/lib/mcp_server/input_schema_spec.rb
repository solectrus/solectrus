# A limit that lives only in the tool's `call` is invisible until it is hit:
# the client sends 30 sensor names, gets an error back, and has burned a round
# trip on something the schema could have told it. JSON Schema carries these
# bounds natively - maxItems, minimum/maximum, default - and every MCP client
# hands the schema to the model before the first call, so a bound stated there
# is a bound the model never crosses. The runtime check stays as the backstop.
#
# The subject is the declared input schema of all tools, not one class.
describe 'MCP input schemas' do # rubocop:disable RSpec/DescribeClass
  def schema_for(tool)
    tool.input_schema.to_h
  end

  def property(tool, name)
    schema_for(tool).dig(:properties, name)
  end

  describe 'the per-request sensor cap' do
    # Each of these enforces its own cap in `call`, so the schema has to state
    # the same number rather than one of its own.
    {
      McpServer::Tools::Series => 20,
      McpServer::Tools::Ranking => 20,
      McpServer::Tools::SensorDetails => 20,
      McpServer::Tools::Totals => 20,
    }.each do |tool, cap|
      it "declares it for #{tool.tool_name}" do
        expect(property(tool, :sensors)).to include(maxItems: cap)
      end

      # Distinct names on purpose: get_ranking unions its `sensor`/`sensors`
      # inputs, so a repeated name collapses before the cap ever sees it.
      it "still rejects more than #{cap} at runtime for #{tool.tool_name}" do
        args = { sensors: Sensor::Config.sensors.map { _1.name.to_s }.take(cap + 1) }
        args[:timeframe] = Date.current.to_s unless tool == McpServer::Tools::SensorDetails

        response = tool.call(server_context: nil, **args)

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('Too many sensors')
      end
    end
  end

  describe 'a list of sensor names' do
    # An empty array is rejected by every tool that requires names; saying so
    # in the schema saves the round trip.
    it 'declares that it cannot be empty' do
      [
        McpServer::Tools::Series,
        McpServer::Tools::Ranking,
        McpServer::Tools::SensorDetails,
        McpServer::Tools::Totals,
      ].each do |tool|
        expect(property(tool, :sensors)).to include(minItems: 1), tool.tool_name
      end
    end
  end

  describe 'the history/entry limit' do
    # Both tools clamp into 1..100 rather than failing, which silently answers
    # a different question than the one asked unless the bound is published.
    [McpServer::Tools::Prices, McpServer::Tools::Ranking].each do |tool|
      it "declares its range and default for #{tool.tool_name}" do
        expect(property(tool, :limit)).to include(minimum: 1, maximum: 100, default: 10)
      end
    end
  end

  describe 'the amortization parameters' do
    it 'declares the ranges the calculator clamps to' do
      expect(property(McpServer::Tools::Amortization, :period_years)).to include(
        minimum: AmortizationCalculator::PERIOD_RANGE.min,
        maximum: AmortizationCalculator::PERIOD_RANGE.max,
        default: AmortizationCalculator::DEFAULT_PERIOD_YEARS,
      )
      expect(property(McpServer::Tools::Amortization, :interest_rate)).to include(
        minimum: AmortizationCalculator::INTEREST_RANGE.min,
        maximum: AmortizationCalculator::INTEREST_RANGE.max,
        default: AmortizationCalculator::DEFAULT_INTEREST_RATE,
      )
    end
  end

  # A default stated in prose has to be read; one stated in the schema is
  # applied. Both are the value the tool's own signature falls back to.
  describe 'the documented defaults' do
    it 'declares them for get_series' do
      expect(property(McpServer::Tools::Series, :aggregation)).to include(default: 'mean')
      expect(property(McpServer::Tools::Series, :include_nulls)).to include(default: true)
    end

    it 'declares them for get_ranking' do
      expect(property(McpServer::Tools::Ranking, :period)).to include(default: 'day')
      expect(property(McpServer::Tools::Ranking, :order)).to include(default: 'desc')
      expect(property(McpServer::Tools::Ranking, :sort)).to include(default: 'value')
    end

    it 'declares them for get_prices' do
      expect(property(McpServer::Tools::Prices, :sort)).to include(default: 'date')
      expect(property(McpServer::Tools::Prices, :order)).to include(default: 'desc')
    end
  end

  # Every declared default has to be one the enum actually allows, or a client
  # applying it sends a value the tool rejects.
  it 'keeps every default within its own enum' do
    offenders =
      McpServer::Server.build.tools.values.flat_map do |tool|
        (tool.input_schema&.to_h&.dig(:properties) || {}).filter_map do |name, spec|
          next unless spec[:enum] && spec.key?(:default)
          next if spec[:enum].include?(spec[:default])

          "#{tool.tool_name}.#{name}"
        end
      end

    expect(offenders).to be_empty
  end
end
