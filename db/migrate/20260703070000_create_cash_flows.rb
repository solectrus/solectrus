class CreateCashFlows < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_flows do |t|
      t.date :date, null: false, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :note, null: false

      t.timestamps
    end
  end
end
