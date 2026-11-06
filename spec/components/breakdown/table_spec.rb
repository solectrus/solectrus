# The including component names the sensors of the breakdown and the value of
# the remainder. A component that names neither cannot build the table.
describe Breakdown::Table do
  subject(:table) { klass.new }

  let(:klass) do
    Class.new { include Breakdown::Table }
  end

  it 'requires the sensors of the breakdown' do
    expect { table.sensor_count }.to raise_error(NotImplementedError)
  end

  context 'with sensors but without the remainder' do
    let(:klass) do
      Class.new do
        include Breakdown::Table

        private

        def breakdown_sensors = []
      end
    end

    it 'requires the value of the remainder' do
      expect { table.common_scaling }.to raise_error(NotImplementedError)
    end
  end
end
