require_relative '../config/environment'
require 'benchmark'

query = nil
execution_time =
  Benchmark.ms do
    query =
      SummaryValue
        .where(date: Date.new(2024, 1, 1)..Date.new(2024, 12, 31))
        .where(aggregation: 'sum')
        .group(:field)
        .sum(:value)
  end

result = query.to_a
result.each { |r| puts(r.inspect) }

puts "Execution Time: #{execution_time.round} ms"
puts

##################################

query = nil
execution_time =
  Benchmark.realtime do
    query =
      SummaryValue
        .where(
          date: Date.new(2024, 1, 1)..Date.new(2024, 12, 31),
          field: 'inverter_power',
          aggregation: 'sum',
        )
        .group_by_month(:date)
        .sum(:value)
  end

query.to_a.each { |r| puts(r.inspect) }

puts "Execution Time: #{(execution_time * 1000).round(2)} ms"
