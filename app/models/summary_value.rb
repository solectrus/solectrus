# == Schema Information
#
# Table name: summary_values
#
#  aggregation :enum             not null, primary key
#  date        :date             not null, primary key
#  field       :enum             not null, primary key
#  value       :float            not null
#
# Indexes
#
#  index_summary_values_on_field_and_aggregation_and_date  (field,aggregation,date)
#
# Foreign Keys
#
#  fk_rails_...  (date => summaries.date) ON DELETE => cascade
#
class SummaryValue < ApplicationRecord
  belongs_to :summary,
             primary_key: :date,
             foreign_key: :date,
             inverse_of: :values

  # Auto-generate from Sensor::Definitions that are stored in summary
  enum :field,
       Sensor::Registry
         .all
         .filter_map { |sensor|
           sensor.name if sensor.summary_aggregations.any?
         }
         .index_with(&:to_s),
       suffix: true,
       enum_type: :field_enum

  # Auto-generate from all aggregation types used by Sensor::Definitions
  enum :aggregation,
       Sensor::Registry
         .all
         .flat_map(&:summary_aggregations)
         .uniq
         .index_with(&:to_s),
       suffix: true,
       enum_type: :aggregation_enum

  validates :field, :aggregation, :value, presence: true

  # The first day of each field, like { 'inverter_power' => date }, without
  # a field that has no value.
  #
  # `where(field:).group(:field).minimum(:date)` reads every value of the
  # fields, as PostgreSQL has no skip scan, so it grows with the number of
  # days. A MIN for a single field stops at its first entry in the index.
  # `unnest` turns the fields into rows, so one query runs that MIN for
  # each of them, without a round trip per field. The array needs the type
  # of the enum column to compare with it.
  def self.first_dates(fields)
    sql = sanitize_sql_array([<<~SQL.squish, fields.map(&:to_s)])
      SELECT fields.field, (SELECT MIN(date) FROM summary_values WHERE summary_values.field = fields.field)
      FROM unnest(ARRAY[?]::field_enum[]) AS fields(field)
    SQL
    connection.select_all(sql).cast_values.to_h.compact
  end
end
