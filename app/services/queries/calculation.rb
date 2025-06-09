class Queries::Calculation
  def initialize(field, aggregation, meta_aggregation, value = nil)
    @field = field.to_sym
    @aggregation = aggregation.to_sym
    @meta_aggregation = meta_aggregation.to_sym
    @value = value

    validate!
  end

  attr_reader :field, :aggregation, :meta_aggregation, :value

  def to_key
    [field, aggregation, meta_aggregation].compact
  end

  def base_key
    [field, aggregation].compact
  end

  def with_value(new_value)
    self.class.new(field, aggregation, meta_aggregation, new_value)
  end

  private

  VALID_META_AGGREGATIONS = %i[sum avg min max].freeze
  private_constant :VALID_META_AGGREGATIONS

  def validate!
    unless SummaryValue.fields.key?(field)
      raise ArgumentError, "Field #{field.inspect} is invalid!"
    end

    unless SummaryValue.aggregations.key?(aggregation)
      raise ArgumentError, "Aggregation #{aggregation.inspect} is invalid!"
    end

    if VALID_META_AGGREGATIONS.exclude?(meta_aggregation)
      raise ArgumentError,
            "Meta aggregation #{meta_aggregation.inspect} is invalid!"
    end

    :ok
  end
end
