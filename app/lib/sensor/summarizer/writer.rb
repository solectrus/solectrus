module Sensor
  class Summarizer
    # Writes the built days of a chunk: a summary for each day and its values.
    # It runs in the transaction of the chunk (see Summarizer#persist).
    class Writer
      # `built` holds an entry for each day (see Summarizer#build)
      def initialize(built)
        @built = built
      end

      def call
        upsert_summaries
        upsert_summary_values(built.flat_map { |entry| entry[:valid_records] })
        cleanup_empty_values
      end

      private

      attr_reader :built

      def upsert_summaries
        return if built.empty?

        now = Time.current

        Summary.upsert_all(
          built.map do |entry|
            {
              date: entry[:date],
              created_at: now,
              updated_at: now,
            }
          end,
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
      def cleanup_empty_values
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
    end
  end
end
