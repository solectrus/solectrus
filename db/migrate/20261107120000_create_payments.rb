# One table for the payments of the cars and of the heat pump (see Payment).
# The column `type` names the class of each payment (Car::Payment or
# Heatpump::Payment), and only a car payment needs a car.
#
# The table is new, and the payments of the cars move to it with their ids.
# A rename would keep the names of the old table in its constraints, so a
# database from the migrations and one from the schema would differ.
class CreatePayments < ActiveRecord::Migration[8.1]
  COLUMNS = 'id, car_id, category, date, amount, note, created_at, updated_at'.freeze
  private_constant :COLUMNS

  def up
    create_table :payments do |t|
      t.string :type, null: false
      t.references :car, foreign_key: true, type: :integer
      t.string :category, null: false
      t.date :date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :note

      t.timestamps

      t.index %i[type date]
      t.check_constraint 'amount <> 0', name: 'payments_amount'
      t.check_constraint "type <> 'Car::Payment' OR car_id IS NOT NULL", name: 'payments_car'
    end

    execute "INSERT INTO payments (type, #{COLUMNS}) SELECT 'Car::Payment', #{COLUMNS} FROM car_payments"
    reset_id_sequence(:payments)
    drop_table :car_payments
  end

  # The payments of the heat pump have no place in the old table, so they
  # are lost
  def down
    create_table :car_payments do |t|
      t.references :car, null: false, foreign_key: true, type: :integer
      t.string :category, null: false
      t.date :date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :note

      t.timestamps

      t.check_constraint 'amount <> 0', name: 'car_payments_amount'
    end

    execute "INSERT INTO car_payments (#{COLUMNS}) SELECT #{COLUMNS} FROM payments WHERE type = 'Car::Payment'"
    reset_id_sequence(:car_payments)
    drop_table :payments
  end

  private

  # The next id follows the highest copied one
  def reset_id_sequence(table)
    execute "SELECT setval(pg_get_serial_sequence('#{table}', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM #{table}"
  end
end
