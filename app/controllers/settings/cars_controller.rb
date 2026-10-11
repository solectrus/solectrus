# The car management page: the name, the short name, the period of use and
# the color of each car. The number of a car comes from its environment variables, and a
# configured number gets its car by itself (see Car.configured), so the page
# adds no car and removes none.
class Settings::CarsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!
  before_action :load_car, only: %i[edit update]

  def index
    @cars = Car.configured
  end

  def edit
  end

  def update
    if @car.update(permitted_params)
      flash.now[:notice] = t('crud.success')
      render turbo_stream: [
               turbo_stream.update('list', partial: 'settings/cars/list', locals: { cars: Car.configured }),
               turbo_stream_update_flash,
             ]
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  helper_method def title
    t('settings.cars.name')
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
