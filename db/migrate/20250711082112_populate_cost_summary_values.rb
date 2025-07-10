class PopulateCostSummaryValues < ActiveRecord::Migration[8.0]
  def up
    # Now that enum values are committed, we can safely populate the summary values
    SummaryUpdater.call
  end

  def down
    # Remove the populated cost summary values
    SummaryValue.where(field: %w[grid_costs grid_revenue]).delete_all
  end
end
