class AddCostFieldsToSummaryValueEnum < ActiveRecord::Migration[8.0]
  def up
    add_enum_value :field_enum, :grid_costs, if_not_exists: true
    add_enum_value :field_enum, :grid_revenue, if_not_exists: true
  end

  def down
    # Note: PostgreSQL does not support removing enum values
    # This would require recreating the enum type
  end
end
