class AddCategoryToCashFlows < ActiveRecord::Migration[8.1]
  # Classify every cash flow so subsidies/refunds no longer count as operating
  # amortization. Existing rows carry only a signed amount, so backfill by sign:
  # outflows become investments, inflows compensation - this reproduces the old
  # credits/debits degree exactly until an admin reclassifies individual entries
  # (e.g. a subsidy).
  def up
    add_column :cash_flows, :category, :string

    execute(<<~SQL.squish)
      UPDATE cash_flows SET category = CASE
        WHEN amount < 0 THEN 'investment'
        ELSE 'compensation'
      END
    SQL

    change_column_null :cash_flows, :category, false
  end

  def down
    remove_column :cash_flows, :category
  end
end
