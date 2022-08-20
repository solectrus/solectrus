class CreatePrices < ActiveRecord::Migration[7.0]
  def change
    create_table :prices do |t|
      t.string :name, null: false
      t.date :starts_at, null: false
      t.decimal :value, precision: 8, scale: 5, null: false
      t.string :note

      t.timestamps

      t.index %i[name starts_at], unique: true
    end

    reversible { |dir| dir.up { Price.seed! } }
  end
end
