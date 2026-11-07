require Rails.root.join('db', 'migrate', '20261107120000_create_payments')

# Runs the migration down and up again. PostgreSQL rolls the changes of the
# schema back with the transaction of the example.
describe CreatePayments do
  subject(:migration) { described_class.new }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1)) }

  def migrate(direction)
    forget_tables
    migration.suppress_messages { migration.migrate(direction) }
    forget_tables
  end

  # Each step changes the tables, so the models and the prepared statements
  # forget what they know of the tables before
  def forget_tables
    ActiveRecord::Base.connection.clear_cache!
    ActiveRecord::Base.descendants.each(&:reset_column_information)
  end

  delegate :connection, to: :'ActiveRecord::Base'

  before do
    car
    migrate(:down)
  end

  # The rollback of the example brings the tables before back
  after { forget_tables }

  it 'moves the payments of the cars with their ids' do
    connection.execute(<<~SQL.squish)
      INSERT INTO car_payments (id, car_id, category, date, amount, note, created_at, updated_at)
      VALUES (5, 1, 'insurance', '2025-03-01', 480, 'Insurance', NOW(), NOW())
    SQL

    migrate(:up)

    expect(Car::Payment.find(5)).to have_attributes(car:, category: 'insurance', amount: 480, note: 'Insurance')
    expect(car.payments.create!(category: :maintenance, date: Date.new(2025, 6, 1), amount: 150).id).to be > 5
  end

  # A payment without a car, like one of the heat pump, has no place in the
  # old table
  it 'keeps the payments of the cars on the way down' do
    migrate(:up)
    car.payments.create!(category: :insurance, date: Date.new(2025, 3, 1), amount: 480)
    connection.execute(<<~SQL.squish)
      INSERT INTO payments (type, category, date, amount, created_at, updated_at)
      VALUES ('Heatpump::Payment', 'maintenance', '2025-06-01', 150, NOW(), NOW())
    SQL

    migrate(:down)

    expect(connection.select_rows('SELECT car_id, category FROM car_payments')).to eq([[1, 'insurance']])
    expect(connection.table_exists?(:payments)).to be(false)
  end
end
