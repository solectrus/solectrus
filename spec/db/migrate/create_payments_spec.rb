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

  # SQL rather than the models, because a model knows the columns that later
  # migrations add
  def insert_payment(values)
    connection.select_value(<<~SQL.squish)
      INSERT INTO payments (type, car_id, category, date, amount, created_at, updated_at)
      VALUES (#{values}, '2025-06-01', 150, NOW(), NOW()) RETURNING id
    SQL
  end

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

    expect(connection.select_rows('SELECT id, type, car_id, category, amount, note FROM payments'))
      .to eq([[5, 'Car::Payment', 1, 'insurance', 480, 'Insurance']])
    expect(insert_payment("'Car::Payment', 1, 'maintenance'")).to be > 5
  end

  # A payment without a car, like one of the heat pump, has no place in the
  # old table
  it 'keeps the payments of the cars on the way down' do
    migrate(:up)
    insert_payment("'Car::Payment', 1, 'insurance'")
    insert_payment("'Heatpump::Payment', NULL, 'maintenance'")

    migrate(:down)

    expect(connection.select_rows('SELECT car_id, category FROM car_payments')).to eq([[1, 'insurance']])
    expect(connection.table_exists?(:payments)).to be(false)
  end
end
