# The car management page: the name, the period of use and the color of each
# car. The number of a car comes from its environment variables, and a
# configured number gets its car by itself (see Car::Provisioning), so the page
# adds no car and removes none.
class Settings::CarsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!
  before_action :load_car, only: %i[edit update]

  def index
    @cars = Car::Provisioning.call
  end

  def edit
  end

  def update
    if @car.update(permitted_params)
      flash.now[:notice] = t('crud.success')
      render turbo_stream: [
               turbo_stream.update('list', partial: 'settings/cars/list', locals: { cars: Car::Provisioning.call }),
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

  # The default color of the number is no color of its own
  def permitted_params
    attributes = params.expect(car: %i[name active_from active_until color])
    attributes[:color] = nil if attributes[:color]&.downcase == Car.default_color(@car.id)
    attributes
  end

  def load_car
    @car = Car::Provisioning.call.find(params.expect(:id))
  end
end
