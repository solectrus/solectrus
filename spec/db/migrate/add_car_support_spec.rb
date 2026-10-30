require Rails.root.join('db', 'migrate', '20260927102209_add_car_support')
require Rails.root.join('db', 'migrate', '20261018100000_add_combustion_comparison')

# Runs the migration down and up again. The payments of a later migration
# refer to the cars, so that migration goes down first and up last.
# PostgreSQL rolls the changes of the schema back with the transaction of
# the example.
describe AddCarSupport do
  subject(:migration) { described_class.new }

  def migrate(direction)
    steps = [migration, AddCombustionComparison.new]
    steps.reverse! if direction == :down
    steps.each do |step|
      forget_tables
      step.suppress_messages { step.migrate(direction) }
    end
    forget_tables
  end

  # Each step changes the tables, so the models and the prepared statements
  # forget what they know of the tables before
  def forget_tables
    ActiveRecord::Base.connection.clear_cache!
    ActiveRecord::Base.descendants.each(&:reset_column_information)
  end

  before { migrate(:down) }

  # The rollback of the example brings the tables before back
  after { forget_tables }

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
