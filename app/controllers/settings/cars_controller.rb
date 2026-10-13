# The car management page: the name, the short name, the period of use and
# the color of each car. The number of a car comes from its environment variables, and a
# configured number gets its car by itself (see Car.configured), so the page
# adds no car and removes none.
class Settings::CarsController < ApplicationController
  include SettingsNavigation
  include FormPageResponse

  before_action :admin_required!
  before_action :load_car, only: %i[edit update]

  def index
    @cars = listed_cars
  end

  def edit
  end

  def update = respond_to_save(@car, @car.update(permitted_params))

  private

  def list_stream
    turbo_stream.update('list', CarList::Component.new(cars: listed_cars))
  end

  helper_method def list_path
    settings_cars_path
  end

  helper_method def title
    t('settings.cars.name')
  end

  # The newest car first, like the prices
  def listed_cars
    Car.configured.sort_by { [it.active_from, it.id] }.reverse
  end

  # The default color is no color of its own
  def permitted_params
    attributes = params.expect(car: %i[name short_name active_from active_until color battery_kwh])
    attributes[:color] = nil if attributes[:color]&.downcase == Car::DEFAULT_COLOR
    attributes
  end

  def load_car
    @car = Car.find_configured!(params.expect(:id))
  end
end
