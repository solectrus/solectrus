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

    # Seed with raw SQL instead of Price.seed!, because a migration must not
    # change with the application code. The model can validate columns or
    # call back into tables that only later migrations add.
    reversible do |dir|
      dir.up do
        date = Rails.configuration.x.installation_date
        execute <<~SQL.squish
          INSERT INTO prices (name, starts_at, value, created_at, updated_at)
          VALUES ('electricity', '#{date}', 0.2545, NOW(), NOW()),
                 ('feed_in', '#{date}', 0.0832, NOW(), NOW())
        SQL
      end
    end
  end
end
