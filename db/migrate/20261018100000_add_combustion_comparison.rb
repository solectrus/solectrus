# The combustion car that a car compares with (docs/cars.md): its fuel, its
# consumption and its yearly tax. A car without a fuel has no comparison. The
# payments of a car, for example its purchase, its insurance or a GHG quota,
# have a category, which gives their direction and tells the comparison
# whether they count (see Car::Payment). A negative amount is a refund.
#
# The models check the fuel and the category, so a new value needs no
# migration.
class AddCombustionComparison < ActiveRecord::Migration[8.1]
  def change
    change_table :cars, bulk: true do |t|
      t.string :fuel_type
      t.decimal :fuel_consumption, precision: 4, scale: 1
      t.decimal :combustion_tax, precision: 8, scale: 2

      t.check_constraint 'fuel_consumption IS NULL OR fuel_consumption > 0', name: 'cars_fuel_consumption'
      t.check_constraint 'combustion_tax IS NULL OR combustion_tax >= 0', name: 'cars_combustion_tax'
    end

    create_table :car_payments do |t|
      t.references :car, null: false, foreign_key: true, type: :integer
      t.string :category, null: false
      t.date :date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :note

      t.timestamps

      t.check_constraint 'amount <> 0', name: 'car_payments_amount'
    end
  end
end
