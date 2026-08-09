# Asking for the same day's peak twice used to give two answers. get_ranking
# with aggregation "max" reads the summaries, whose min/max the summarizer
# aggregates over 5-minute means; get_series with aggregation "max" reads the
# samples themselves. On a measured day that was 8800.6 W against 9536 W - 8 %
# apart, both correct, and whichever tool the client happened to call decided
# the number it reported as "the peak".
#
# The gap is by design and stays. What could not stay is that neither schema
# said so: get_series claimed its max is the true instantaneous peak, which
# only implies that get_ranking's is something else, while get_ranking's
# `aggregation` said nothing at all. So each side now states the shared fact
# and points at the other, and a client reads a peak as qualified rather than
# discovering the disagreement by calling twice.
#
# Asserted on the schemas because that is where the client reads it, before
# the call it would otherwise get wrong.
#
# The subject is the agreement between two tools, not one class.
describe 'MCP peak disclosure' do # rubocop:disable RSpec/DescribeClass
  def aggregation_description(tool)
    tool.input_schema.to_h.dig(:properties, :aggregation, :description).squish
  end

  {
    'get_ranking' => McpServer::Tools::Ranking,
    'get_series' => McpServer::Tools::Series,
  }.each do |name, tool|
    it "states in #{name} what a summary min/max is taken over" do
      expect(aggregation_description(tool)).to include(
        McpServer::Facts::SUMMARY_EXTREMES,
      )
    end
  end

  # Each half is useless alone: knowing the summary averages first does not
  # tell a client where to get the raw peak, and knowing get_series reads
  # samples does not tell it why the ranking disagrees.
  it 'sends get_ranking to get_series for the raw peak' do
    expect(aggregation_description(McpServer::Tools::Ranking)).to include(
      'get_series',
    )
  end

  it 'tells get_series that the ranked period reads lower' do
    expect(aggregation_description(McpServer::Tools::Series)).to include(
      'get_ranking',
    )
  end
end
