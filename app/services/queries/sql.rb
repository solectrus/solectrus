class Queries::Sql
  # Initialize with calculations and optional date range
  # Example:
  #
  # calculations = [
  #   Queries::Calculation.new(:inverter_power, :sum, :sum),
  #   Queries::Calculation.new(:house_power, :sum, :sum),
  # ]
  def initialize(calculations, from: nil, to: nil)
    @from = [from, Rails.application.config.x.installation_date].compact.max
    @to = to
    @calculations = calculations

    raise ArgumentError unless calculations.all?(Queries::Calculation)
  end

  attr_reader :from, :to, :calculations

  def value(field, aggregation, meta_aggregation)
    call.find { it.to_key == [field, aggregation, meta_aggregation] }&.value
  end

  def to_hash
    call.each_with_object({}) { |calc, hash| hash[calc.to_key] = calc.value }
  end

  private

  def call
    @call ||=
      begin
        grouped_totals =
          totals.group_by { |row| [row.field.to_sym, row.aggregation.to_sym] }

        calculations.map do |calc|
          total = grouped_totals[calc.base_key]&.first
          value = total&.public_send(calc.meta_aggregation)
          calc.with_value(value)
        end
      end
  end

  def totals
    @totals ||=
      SummaryValue
        .select(select_fields)
        .where(date: from..to)
        .where(build_conditions)
        .group(:field, :aggregation)
        .to_a
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
    meta_aggregations = calculations.map(&:meta_aggregation)
    meta_aggregations.uniq!

    aggregation_functions =
      meta_aggregations.map { |agg| "#{agg.upcase}(value) AS #{agg}" }

    (base_fields + aggregation_functions).join(', ')
  end

  # Build the WHERE conditions with IN ARRAY
  def build_conditions
    fields = calculations.map(&:field)
    aggregations = calculations.map(&:aggregation)

    # Extract unique fields and aggregations for the IN query
    { field: fields.uniq, aggregation: aggregations.uniq }
  end
end
