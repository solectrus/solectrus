require Rails.root.join('db', 'migrate', '20260927102209_add_cars')

# Runs the migration down to the database of v1.3 and up again. PostgreSQL
# rolls the changes of the schema back with the transaction of the example.
describe AddCars do
  subject(:migration) { described_class.new }

  def migrate(direction)
    migration.suppress_messages { migration.migrate(direction) }
  end

  # In SQL, because the models know the columns after the migration
  def insert_soc(field)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO summaries (date, created_at, updated_at) VALUES ('2026-01-01', now(), now());
      INSERT INTO summary_values (date, field, aggregation, value) VALUES ('2026-01-01', '#{field}', 'avg', 60)
    SQL
  end

  def soc_fields
    ActiveRecord::Base.connection.select_values('SELECT field FROM summary_values')
  end

  before { migrate(:down) }

  it 'keeps the daily values of car_battery_soc as the first car' do
    insert_soc('car_battery_soc')

    migrate(:up)

    expect(soc_fields).to eq(['car_battery_soc_1'])
  end

  it 'moves the name of car_battery_soc to the first car' do
    Setting.sensor_names = { 'car_battery_soc' => 'Model Y', 'house_power' => 'House' }

    migrate(:up)

    expect(Car.find(1)).to have_attributes(name: 'Model Y', active_from: Rails.configuration.x.installation_date)
    expect(Setting.sensor_names).to eq('house_power' => 'House')
  end

  it 'makes no car without a name' do
    Setting.sensor_names = { 'car_battery_soc' => '' }

    migrate(:up)

    expect(Car.count).to eq(0)
    expect(Setting.sensor_names).to eq({})
  end

  it 'gives the name back on the way down' do
    Setting.sensor_names = { 'car_battery_soc' => 'Model Y' }
    migrate(:up)

    migrate(:down)

    expect(Setting.sensor_names).to eq('car_battery_soc' => 'Model Y')
  end
end
