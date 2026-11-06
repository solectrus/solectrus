# No route takes an admin-only sensor today: the location of a car has no
# chart and no Top 10, so the route constraints answer 404 first (see
# spec/requests/admin_only_sensors_request_spec.rb). This is the second line:
# a controller with ParamsHandling takes its sensor straight from the URL, so
# it must refuse an admin-only sensor to a visitor, whatever the routing
# allows tomorrow.
describe ParamsHandling do
  subject(:check) { controller.__send__(:forbid_admin_only_sensor) }

  let(:controller) do
    TilesController.new.tap do |instance|
      allow(instance).to receive_messages(sensor_name:, admin?: admin)
    end
  end

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
  end

  after { Sensor::Config.setup(ENV) }

  context 'with an admin-only sensor' do
    let(:sensor_name) { :car_latitude_1 }

    context 'when visitor' do
      let(:admin) { false }

      it { expect { check }.to raise_error(ForbiddenError) }
    end

    context 'when admin' do
      let(:admin) { true }

      it { is_expected.to be(true) }
    end
  end

  context 'with an ordinary sensor' do
    let(:sensor_name) { :house_power }
    let(:admin) { false }

    it { is_expected.to be_nil }
  end
end
