require Rails.root.join('db', 'migrate', '20260927102209_add_car_support')

# Runs the migration down to the database of develop and up again. PostgreSQL
# rolls the changes of the schema back with the transaction of the example.
describe AddCarSupport do
  subject(:migration) { described_class.new }

  def migrate(direction)
    migration.suppress_messages { migration.migrate(direction) }
  end

  before { migrate(:down) }

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
