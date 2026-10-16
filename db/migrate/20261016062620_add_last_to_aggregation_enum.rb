# The state of charge of a car at the end of a day (see Car::Driving)
class AddLastToAggregationEnum < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :aggregation_enum, :last, if_not_exists: true
  end

  def down
    # Not possible to remove enum values
  end
end
