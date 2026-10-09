module Sensor
  class Summarizer
    # How many days one run pulls from InfluxDB in a single Flux program.
    #
    # Larger batches keep getting a little faster, but the gain flattens out
    # and a batch is also what one request, one failure and one step of the
    # progress bar cover. Measured over 7 days of data at the real 5s rate,
    # a batch stays at 1.7s even with InfluxDB throttled to half a core -
    # well inside the HTTP read timeout, which doubling this would start to
    # eat into.
    #
    # Note what the batching does and does not buy: InfluxDB reads the same
    # data either way (allocations differ by under 6%), so the speedup comes
    # from spreading a batch over the cores rather than from doing less. With
    # no spare cores it is a wash - while the single transaction per batch
    # helps regardless, and most of all on a spinning disk.
    CHUNK_SIZE = 7
    public_constant :CHUNK_SIZE

    # Summarize a single date, a range of dates or a timeframe
    def self.call(date_or_timeframe)
      case date_or_timeframe
      when Date
        new([date_or_timeframe]).call
      when Range
        # Days that turn out to be fresh are dropped in #pending_summaries, so
        # a range with gaps costs no more than the days it really has to build.
        new(date_or_timeframe.to_a).call
      when Timeframe
        raise ArgumentError if date_or_timeframe.now?

        new(Summary.missing_or_stale_days_for(date_or_timeframe)).call
      else
        raise ArgumentError,
              "Expected Date, Range or Timeframe, got #{date_or_timeframe.class}"
      end
    end

    def initialize(dates)
      @dates = Array(dates)
    end

    attr_reader :dates

    # Returns the number of days that were (re)built
    def call
      count = dates.each_slice(CHUNK_SIZE).sum { |chunk| process(chunk) }

      # The days that lost the increase of a meter to a gap go, so they are
      # missing now. One more round builds them at once, and no page has to
      # wait for them. A gap that this round finds waits for the next build.
      repaired = gap_dates.uniq.sort
      @gap_dates = []
      count + repaired.each_slice(CHUNK_SIZE).sum { |chunk| process(chunk) }
    end

    private

    # ============================================
    # One chunk of days
    # ============================================

    def process(chunk)
      pending = pending_summaries(chunk)
      return 0 if pending.empty?

      # Each step waits for InfluxDB, so it overlaps with the queries and the
      # build of the values. It needs no database once made.
      dates = pending.map(&:first)
      steps = start_steps(dates)
      batch = batch_for(dates)
      diffs = meter_diffs(dates, batch)
      gaps = MeterGaps.new(dates, diffs, built: built_dates)

      # Building the values needs no transaction, and holding one open across
      # every InfluxDB query of a chunk would keep it running for as long as
      # the slowest of them.
      built = build(pending, batch ? batch.call : {}, diffs, batch&.states)
      steps.each(&:result)
      gaps.result
      persist(built, steps, gaps)
      built_dates.merge(dates)

      built.size
    end

    # The days that this run built, so each of them saw every reading up to
    # now (see MeterGaps)
    def built_dates
      @built_dates ||= Set.new
    end

    def gap_dates
      @gap_dates ||= []
    end

    # Days whose summary is missing or stale, paired with the record to write.
    # Checked before any InfluxDB query, so a day that turns out to be fresh
    # costs nothing.
    def pending_summaries(chunk)
      existing = Summary.where(date: chunk).index_by(&:date)

      chunk.filter_map do |date|
        summary = existing[date] || Summary.new(date:)
        next unless summary.new_record? || summary.stale?(current_tolerance: 0)

        [date, summary]
      end
    end

    # A run of each step with something to do, on each day of the build (see
    # Summary::Steps)
    def start_steps(dates)
      steps = Summary::Steps.enabled
      return [] if steps.empty?

      # The steps share what they read alike, for example the curves of the
      # cars, so one Flux program reads it (see Summary::Steps.shared)
      shared = Summary::Steps.shared(dates)
      steps.map { StepRun.new(it, dates, shared) }
    end

    # Each day reads the meters from the diffs that the chunk shares with its
    # gaps (see #meter_diffs), and the states from the batch
    def build(pending, prefetched, meter_diffs, states)
      pending.map do |date, summary|
        data =
          Sensor::SummaryBuilder.new(
            Timeframe.new(date.iso8601),
            prefetched: prefetched[date],
            meter_diffs:,
            states:,
          ).call

        records = summary_records(date, data)

        {
          date:,
          new_record: summary.new_record?,
          records:,
          # Zero is a value of its own (the battery simply did not charge),
          # only nil means there was no data at all
          valid_records: records.reject { |record| record[:value].nil? },
        }
      end
    end

    # The gaps of the meters read the points of the daily increase, so the
    # build and the gaps share one query (see MeterGaps)
    def meter_diffs(dates, batch)
      batch&.meter_diffs || Sensor::Query::Helpers::Influx::DailyDiffs.new(dates, Sensor::SummaryBuilder.meter_sensor_names)
    end

    # A single day is left to the per-day queries: batching one day would only
    # build the same pipelines under a cache key nothing else shares.
    def batch_for(dates)
      return if dates.size < 2

      Sensor::Query::Helpers::Influx::DailyBatch.new(
        dates,
        sum_sensor_names: Sensor::SummaryBuilder.sum_sensor_names,
        aggregation_sensor_names:
          Sensor::SummaryBuilder.aggregation_sensor_names,
        meter_sensor_names: Sensor::SummaryBuilder.meter_sensor_names,
        state_sensor_names: Sensor::SummaryBuilder.state_sensor_names,
      )
    end

    # ============================================
    # Database persistence
    # ============================================

    # Everything a chunk writes goes into one transaction: on a spinning disk
    # each commit costs an fsync, which dominated the writes when every day
    # committed on its own.
    #
    # The steps write in the same transaction (see StepRun#persist)
    def persist(built, steps, gaps)
      ActiveRecord::Base.transaction do
        Writer.new(built).call
        steps.each(&:persist)
        gap_dates.concat(gaps.remove!(built.pluck(:date)))
      end
    end

    # ============================================
    # Record building
    # ============================================

    def summary_records(date, summary_data)
      # Direct enumeration with each_with_object for better performance
      summary_data
        .raw_data
        .each_with_object([]) do |(key, value), records|
          next unless key.is_a?(Array) && key.length == 2

          sensor_name, aggregation = key
          next unless sensor_name.is_a?(Symbol) && aggregation.is_a?(Symbol)

          records << {
            field: sensor_name.to_s,
            aggregation: aggregation.to_s,
            value: (value if recorded?(sensor_name, date)),
            date:,
          }
        end
    end

    # A day on which the sensor records nothing, like a car outside its period
    # of use, gets no value, and #cleanup_empty_values removes an existing one
    def recorded?(sensor_name, date)
      definition = Sensor::Registry.find(sensor_name)
      definition.nil? || definition.recorded_on?(date)
    end
  end
end
