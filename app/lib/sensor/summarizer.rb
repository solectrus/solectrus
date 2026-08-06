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
      dates.each_slice(CHUNK_SIZE).sum { |chunk| process(chunk) }
    end

    private

    # ============================================
    # One chunk of days
    # ============================================

    def process(chunk)
      pending = pending_summaries(chunk)
      return 0 if pending.empty?

      # Building the values needs no transaction, and holding one open across
      # every InfluxDB query of a chunk would keep it running for as long as
      # the slowest of them.
      built = build(pending)
      persist(built)

      built.size
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

    def build(pending)
      prefetched = prefetch(pending.map(&:first))

      pending.map do |date, summary|
        data =
          Sensor::SummaryBuilder.new(
            Timeframe.new(date.iso8601),
            prefetched: prefetched[date],
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

    # A single day is left to the per-day queries: batching one day would only
    # build the same pipelines under a cache key nothing else shares.
    def prefetch(dates)
      return {} if dates.size < 2

      Sensor::Query::Helpers::Influx::DailyBatch.new(
        dates,
        sum_sensor_names: Sensor::SummaryBuilder.sum_sensor_names,
        aggregation_sensor_names:
          Sensor::SummaryBuilder.aggregation_sensor_names,
      ).call
    end

    # ============================================
    # Database persistence
    # ============================================

    # Everything a chunk writes goes into one transaction: on a spinning disk
    # each commit costs an fsync, which dominated the writes when every day
    # committed on its own.
    def persist(built)
      ActiveRecord::Base.transaction do
        upsert_summaries(built)
        upsert_summary_values(built.flat_map { |entry| entry[:valid_records] })
        cleanup_empty_values(built)
      end
    end

    def upsert_summaries(built)
      now = Time.current

      Summary.upsert_all(
        built.map { |entry| { date: entry[:date], created_at: now, updated_at: now } },
        unique_by: :date,
        # A day that is already there only gets touched, and Rails must not add
        # a touch of its own - it would assign updated_at twice in one
        # statement, which Postgres rejects.
        update_only: %i[updated_at],
        record_timestamps: false,
      )
    end

    def upsert_summary_values(records)
      return if records.empty?

      SummaryValue.upsert_all(
        records,
        unique_by: %i[date aggregation field],
        update_only: %i[value],
      )
    end

    # Delete values that exist but have no value anymore (rare case). Only a
    # summary that was there before can have any, so a new one is skipped.
    def cleanup_empty_values(built)
      empty_records =
        built.flat_map do |entry|
          next [] if entry[:new_record]

          entry[:records] - entry[:valid_records]
        end
      return if empty_records.empty?

      build_deletion_query(empty_records)&.delete_all
    end

    def build_deletion_query(records)
      records.reduce(nil) do |query, record|
        condition =
          SummaryValue.where(record.slice(:date, :aggregation, :field))
        query&.or(condition) || condition
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
            value:,
            date:,
          }
        end
    end
  end
end
