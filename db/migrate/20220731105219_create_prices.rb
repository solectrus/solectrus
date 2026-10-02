class CreatePrices < ActiveRecord::Migration[7.0]
  # Without the callbacks of Price, which need tables of later migrations
  class MigrationPrice < ActiveRecord::Base
    self.table_name = 'prices'
  end
  private_constant :MigrationPrice

  def change
    create_table :prices do |t|
      t.string :name, null: false
      t.date :starts_at, null: false
      t.decimal :value, precision: 8, scale: 5, null: false
      t.string :note

      t.timestamps

      t.index %i[name starts_at], unique: true
    end

    reversible { |dir| dir.up { seed } }
  end

  private

  # The default prices of Price.seed!, repeated here because a migration must
  # not change with the application code
  def seed
    { 'electricity' => 0.2545, 'feed_in' => 0.0832 }.each do |name, value|
      MigrationPrice.create!(name:, starts_at: Rails.configuration.x.installation_date, value:)
    end
  end
end
