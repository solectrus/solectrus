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

  # The grammar is published as a closed set, so a client takes each
  # parenthesis for a promise about what the form covers - and only ONE of the
  # three P-forms rolls. Timeframe ends an hour window at Time.current, but a
  # day window yesterday and a month window with last month. While all three
  # were called "a rolling window ending now", a client reported a P30D total
  # as "the last 30 days" including today, and the day window it had actually
  # been given stops before today.
  describe 'the published timeframe grammar' do
    let(:grammar) { McpServer::Facts::TIMEFRAME_FORMS }

    def timeframe_tools
      McpServer::Server.build.tools.values.select { property(it, :timeframe) }
    end

    it 'reaches every tool that takes a timeframe' do
      expect(timeframe_tools).not_to be_empty
      timeframe_tools.each do |tool|
        expect(property(tool, :timeframe)[:description]).to include(grammar),
                                                            tool.tool_name
      end
    end

    it 'calls the hour window rolling, and only that one' do
      expect(grammar).to include('"P24H" (a rolling window ending NOW)')
      expect(grammar).not_to include('"P24H"/"P30D"/"P12M"')
    end

    it 'agrees with Timeframe on the hour window' do
      freeze_time

      expect(Timeframe.new('P24H').ending).to eq(Time.current)
    end

    it 'agrees with Timeframe on the day window' do
      expect(grammar).to include('ending yesterday')
      expect(Timeframe.new('P30D').ending.to_date).to eq(Date.yesterday)
    end

    it 'agrees with Timeframe on the month window' do
      expect(grammar).to include('ending with last month')
      expect(Timeframe.new('P12M').ending.to_date).to be < Date.current.beginning_of_month
    end

    # The one clause a client acts on: whether a figure it is about to report
    # can contain a day that is only half measured.
    it 'says that neither reaches into today' do
      expect(grammar).to include('neither of those two reaches into today')
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
