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
end
