class Queries::Sql
  # Initialize with calculations hash and optional date range
  # Example:
  # calculations = [
  #   :sum_inverter_power_sum,
  #   :sum_house_power_sum
  # ]
  def initialize(calculations:, from: nil, to: nil)
    raise ArgumentError, 'No calculations given' if calculations.blank?
    unless calculations.is_a?(Array)
      raise ArgumentError, "Array expected, got #{calculations.class}"
    end

    @from = [from, Rails.application.config.x.installation_date].compact.max
    @to = to
    @calculations = calculations
  end

  attr_reader :from, :to, :calculations

  def respond_to_missing?(method, include_private = false)
    to_hash.key?(method) || super
  end

  def method_missing(method)
    to_hash.key?(method) ? to_hash[method] : super
  end

  private

  def to_hash
    @to_hash ||=
      calculations
        .index_with { nil }
        .merge(
          totals.to_h do |row|
            [:"sum_#{row.field}_#{row.aggregation}", row.sum]
          end,
        )
        .merge(
          totals.to_h do |row|
            [:"min_#{row.field}_#{row.aggregation}", row.min]
          end,
        )
        .merge(
          totals.to_h do |row|
            [:"max_#{row.field}_#{row.aggregation}", row.max]
          end,
        )
        .merge(
          totals.to_h do |row|
            [:"avg_#{row.field}_#{row.aggregation}", row.avg]
          end,
        )
  end

  # Build and execute the query
  def totals
    @totals ||=
      SummaryValue
        .select(select_fields)
        .where(date: from..to)
        .where(build_conditions)
        .group(:field, :aggregation)
  end

  # Build the SELECT fields dynamically, e.g:
  #
  #    SELECT
  #      field,
  #      aggregation,
  #      SUM(value),
  #      AVG(value),
  #      MIN(value),
  #      MAX(value)
  def select_fields
    base_fields = %i[field aggregation]
    aggregation_functions =
      %i[SUM AVG MIN MAX].map { |func| "#{func}(value) AS #{func.downcase}" }

    (base_fields + aggregation_functions).join(', ')
  end

  # Build the WHERE conditions with IN ARRAY
  def build_conditions
    fields_and_aggregations =
      calculations.map do |calculation|
        list = calculation.to_s.split('_')
        aggregation = list.last
        field = list[1..-2].join('_')

        { field:, aggregation: }
      end

    # Extract unique fields and aggregations for the IN query
    fields = fields_and_aggregations.pluck(:field).uniq
    aggregations = fields_and_aggregations.pluck(:aggregation).uniq

    # Return a single condition
    { field: fields, aggregation: aggregations }
  end
end
