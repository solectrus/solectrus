class AddAmountPerMonthToPrices < ActiveRecord::Migration[8.1]
  def change
    add_column :prices, :amount_per_month, :decimal, precision: 8, scale: 2
  end
end
