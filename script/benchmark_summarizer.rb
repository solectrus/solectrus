#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark script for Sensor::Summarizer performance testing
#
# This script measures the performance of creating daily summaries
# for a given date range. It's useful for:
# - Testing performance improvements in SummaryBuilder
# - Comparing different InfluxDB query optimizations
# - Identifying performance regressions
#
# Usage:
#   # Default (last 30 days)
#   rails runner script/benchmark_summarizer.rb
#
#   # Last 7 days
#   DAYS=7 rails runner script/benchmark_summarizer.rb
#
# Environment variables:
#   DAYS - Number of days to process (counting back from yesterday, default: 30)
#
# The script will:
# 1. Delete existing summaries for the date range
# 2. Clear the Rails cache
# 3. Create summaries for all days in the range
# 4. Report average time per day and total time

require 'benchmark'

puts '=' * 80
puts 'SENSOR SUMMARIZER PERFORMANCE BENCHMARK'
puts '=' * 80
puts

# Parse date range from environment or use default
days = ENV.fetch('DAYS', 30).to_i
end_date = Date.yesterday
start_date = end_date - (days - 1).days

dates = (start_date..end_date).to_a

puts "Date range: #{start_date} to #{end_date} (#{dates.size} days)"
puts

# Delete existing summaries
puts "Deleting existing summaries for #{start_date} to #{end_date}..."
deleted_count = Summary.where(date: start_date..end_date).delete_all
puts "Deleted #{deleted_count} summaries"
puts

# Clear cache to ensure fair comparison
Rails.cache.clear
puts 'Cache cleared'
puts

# Suppress InfluxDB query logs during benchmark
Rails.logger = Logger.new(nil)

# Warm-up: Run one summary to establish DB connections
puts 'Warming up (establishing database connections)...'
warmup_date = dates.first
warmup_time = Benchmark.realtime { Sensor::Summarizer.call(warmup_date) }
puts "Warm-up complete (took #{(warmup_time * 1000).round}ms)"
puts

# Run the summarizer for remaining days (skip first since it was used for warm-up)
remaining_dates = dates.drop(1)

if remaining_dates.empty?
  puts 'Only 1 day requested - benchmark complete with warm-up run only'
  puts
  puts '=' * 80
  puts 'BENCHMARK RESULTS'
  puts '=' * 80
  puts
  puts "Date range:        #{start_date} to #{end_date}"
  puts 'Days processed:    1 (warm-up only)'
  puts "Warm-up time:      #{(warmup_time * 1000).round}ms"
  puts
  summaries_count = Summary.where(date: start_date..end_date).count
  summary_values_count = SummaryValue.where(date: start_date..end_date).count
  puts "Summaries created: #{summaries_count}"
  puts "SummaryValues created: #{summary_values_count}"
  puts '=' * 80
  exit
end

puts "Running Summarizer for #{remaining_dates.size} days..."
puts

times = []
total_time =
  Benchmark.realtime do
    remaining_dates.each_with_index do |date, index|
      time = Benchmark.realtime { Sensor::Summarizer.call(date) }
      times << time

      print "\rProgress: #{index + 1}/#{remaining_dates.size} days (#{((index + 1).to_f / remaining_dates.size * 100).round}%) - Last: #{(time * 1000).round}ms"
    end
  end

puts
puts
puts '=' * 80
puts 'BENCHMARK RESULTS'
puts '=' * 80

# Calculate statistics
sorted_times = times.sort
median = sorted_times[sorted_times.size / 2]
min = sorted_times.first
max = sorted_times.last
avg = total_time / remaining_dates.size

puts
puts "Date range:        #{start_date} to #{end_date}"
puts "Days processed:    #{remaining_dates.size} (+ 1 warm-up)"
puts "Total time:        #{total_time.round(2)}s"
puts
puts 'Performance per day:'
puts "  Average:         #{(avg * 1000).round}ms"
puts "  Median:          #{(median * 1000).round}ms"
puts "  Min:             #{(min * 1000).round}ms"
puts "  Max:             #{(max * 1000).round}ms"
puts "  Warm-up:         #{(warmup_time * 1000).round}ms (excluded from stats)"
puts
summaries_count = Summary.where(date: start_date..end_date).count
summary_values_count = SummaryValue.where(date: start_date..end_date).count
puts "Summaries created: #{summaries_count}"
puts "SummaryValues created: #{summary_values_count}"
puts '=' * 80
