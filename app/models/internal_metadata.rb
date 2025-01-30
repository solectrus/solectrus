# Accessor for the `internal_metadata`` table
# This should be part of Rails, but it's not
class InternalMetadata < ApplicationRecord
  self.table_name = 'ar_internal_metadata' # rubocop:disable Rails/TableNameAssignment
  self.primary_key = 'key'

  def self.created_at
    where(key: 'environment').pick(:created_at)
  end
end
