module Sensor
  class Summarizer
    def initialize(date)
      @date = date
      @timeframe = Timeframe.new(date.iso8601)
      @prices = {}
    end

    attr_reader :date, :timeframe

    def call
      return unless sensor_attributes

      ActiveRecord::Base.transaction do
        summary = find_or_create_summary
        return unless summary_needs_update?(summary)

        update_summary_record(summary)
        persist_summary_values(updating: !summary.new_record?)
      rescue ActiveRecord::RecordNotUnique
        # Race condition: Another job has created the summary in the meantime
        # We can safely ignore this error
        #
        # :nocov:
        Rails.logger.warn("Summary for #{date} already exists.")
        # :nocov:
      end
    end

    private

    def find_or_create_summary
      Summary.where(date:).first || Summary.new(date:)
    end

    def summary_needs_update?(summary)
      summary.new_record? || summary.stale?(current_tolerance: 0)
    end

    def update_summary_record(summary)
      summary.new_record? ? summary.save! : summary.touch
    end

    # ============================================
    # Sensor attribute building
    # ============================================

    def sensor_attributes
      @sensor_attributes ||= Sensor::SummaryBuilder.new(timeframe).call
    end

    # ============================================
    # Database persistence
    # ============================================

    def persist_summary_values(updating: false)
      summary_records = prepare_summary_records
      valid_records = filter_valid_records(summary_records)

      upsert_summary_values(valid_records)

      # Delete empty values, which may exists before (rare case)
      cleanup_empty_values(summary_records, valid_records) if updating
    end

    def prepare_summary_records
      summary_data = sensor_attributes

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

    def filter_valid_records(records)
      records.select { |record| record_has_valid_value?(record) }
    end

    def record_has_valid_value?(record)
      value, aggregation = record.values_at(:value, :aggregation)

      if aggregation == 'sum'
        value&.nonzero?
      else
        value.present?
      end
    end

    def upsert_summary_values(records)
      return if records.empty?

      SummaryValue.upsert_all(
        records,
        unique_by: %i[date aggregation field],
        update_only: %i[value],
      )
    end

    def cleanup_empty_values(all_records, valid_records)
      empty_records = all_records - valid_records
      return if empty_records.empty?

      deletion_query = build_deletion_query(empty_records)
      deletion_query&.delete_all
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
