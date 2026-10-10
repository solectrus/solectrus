module Sensor
  module Query
    module Helpers
      module Influx
        # Collects the values a daily summary needs for many days at once.
        #
        # A Flux query costs roughly the same whether it spans an hour or a
        # day, so a per-day summary run pays for the request, not for the data.
        # This class keeps the per-day pipelines exactly as Integral and
        # Aggregation build them - same range, same filter, same functions,
        # hence the same values - and only unions them into a single program
        # per kind. Measured against a remote InfluxDB, that took a 30-day
        # rebuild from 2265 ms down to 535 ms.
        #
        # The obvious alternative, letting InfluxDB cut the range into days
        # itself, was measured to be 4-11x SLOWER: both a custom aggregate
        # function (`aggregateWindow(fn: integral)`) and the `location` option
        # needed for local midnights defeat its pushdown. Handing it explicit
        # per-day ranges avoids that and gets DST right for free, because
        # Timeframe already knows that a day can have 23 or 25 hours.
        class DailyBatch
          # The column every row is tagged with, so one response can be split
          # back into per-day results.
          DAY = 'day'.freeze
          private_constant :DAY

          def initialize(dates, sum_sensor_names:, aggregation_sensor_names:, meter_sensor_names:, state_sensor_names: [])
            @dates = dates
            @sum_sensor_names = sum_sensor_names
            @aggregation_sensor_names = aggregation_sensor_names
            @meter_sensor_names = meter_sensor_names
            @meter_diffs = DailyDiffs.new(dates, meter_sensor_names)
            @states = DailyStates.new(dates, state_sensor_names)
          end

          attr_reader :dates, :sum_sensor_names, :aggregation_sensor_names, :meter_sensor_names

          # The daily increase of the meters. Sensor::SummaryBuilder and
          # Sensor::Summarizer::MeterGaps read it.
          attr_reader :meter_diffs

          # The daily min, max and avg of the states. Sensor::SummaryBuilder
          # reads it.
          attr_reader :states

          # => { Date => { sum: Sensor::Data::Single, aggregation: ... } }
          #
          # A value is nil when that kind was not asked for at all; the caller
          # then falls back to querying the day on its own. The diffs of the
          # meters and the values of the states are ready in #meter_diffs and
          # #states afterwards.
          def call
            # The programs are independent, so they overlap just like the
            # per-day queries they replace.
            sum = Concurrent::Future.execute { resolve(:sum) }
            aggregation = Concurrent::Future.execute { resolve(:aggregation) }
            diff = Concurrent::Future.execute { meter_diffs.call }
            state = Concurrent::Future.execute { states.call }

            sums = sum.value!
            aggregations = aggregation.value!
            diff.wait!
            state.wait!

            dates.index_with { { sum: sums[it], aggregation: aggregations[it] } }
          end

          private

          # Answers one query per day, taking from the cache what is already
          # there and fetching the rest in a single program.
          def resolve(kind)
            queries = queries_for(kind)
            return {} if queries.empty?

            results = {}
            pending = {}

            queries.each do |date, query|
              rows = query.cached_rows
              rows ? results[date] = query.call_with(rows) : pending[date] = query
            end

            unless pending.empty?
              rows_by_date = fetch(kind, pending)

              pending.each do |date, query|
                results[date] = query.call_with(rows_by_date[date] || [], cache: true)
              end
            end

            results
          end

          def fetch(kind, pending)
            rows = FluxProgram.query(flux_for(kind, pending), class_name: self.class.name, sensors: sensor_names_for(kind))

            rows.group_by { |row| Date.parse(row[DAY]) }
          end

          def queries_for(kind)
            names = sensor_names_for(kind)
            return {} if names.empty?

            dates.index_with do |date|
              query_class(kind).new(names, timeframe_for(date))
            end
          end

          def sensor_names_for(kind)
            kind == :sum ? sum_sensor_names : aggregation_sensor_names
          end

          def query_class(kind)
            kind == :sum ? Integral : Aggregation
          end

          def timeframe_for(date)
            @timeframes ||= {}
            @timeframes[date] ||= Timeframe.new(date.iso8601)
          end

          def flux_for(kind, pending)
            # Every query of a kind selects the same sensors, so any of them can
            # state the selection - which keeps it in one place.
            predicate = pending.values.first.flux_predicate

            if kind == :sum
              sum_flux(pending.keys, predicate)
            else
              aggregation_flux(pending.keys, predicate)
            end
          end

          # One stream per day, each the very pipeline Integral would run.
          def sum_flux(pending_dates, predicate)
            streams =
              pending_dates.map.with_index do |date, index|
                <<~FLUX
                  s#{index} = source(#{range_args(date)})
                    |> integral(unit: 1h)
                    |> tag(day: "#{date}")
                FLUX
              end

            <<~FLUX
              #{FluxProgram.source(predicate)}
              tag = (day, tables=<-) => tables
                |> set(key: "#{DAY}", value: day)
                |> keep(columns: ["_value", "#{DAY}", "_field", "_measurement"])

              #{streams.join}
              #{combine(streams.size, 's')}
            FLUX
          end

          # The same for Aggregation, including its pivot, so the rows arrive
          # in the shape its parser already expects.
          def aggregation_flux(pending_dates, predicate)
            streams =
              pending_dates.map.with_index do |date, index|
                <<~FLUX
                  c#{index} = () => source(#{range_args(date)})
                    |> aggregateWindow(every: 5m, fn: mean)
                  a#{index} = union(tables: [
                      c#{index}() |> min() |> operation(name: "min"),
                      c#{index}() |> max() |> operation(name: "max"),
                      c#{index}() |> mean() |> operation(name: "avg"),
                    ])
                    |> pivot(rowKey: ["_field", "_measurement"], columnKey: ["operation"], valueColumn: "_value")
                    |> set(key: "#{DAY}", value: "#{date}")
                FLUX
              end

            <<~FLUX
              #{FluxProgram.source(predicate)}
              operation = (name, tables=<-) => tables
                |> set(key: "operation", value: name)
                |> keep(columns: ["_value", "operation", "_field", "_measurement"])

              #{streams.join}
              #{combine(streams.size, 'a')}
            FLUX
          end

          def range_args(date)
            timeframe = timeframe_for(date)

            FluxProgram.range_args(timeframe.beginning, timeframe.ending)
          end

          def combine(count, prefix)
            FluxProgram.union(Array.new(count) { |index| "#{prefix}#{index}" })
          end
        end
      end
    end
  end
end
