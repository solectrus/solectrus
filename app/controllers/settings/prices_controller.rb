class Settings::PricesController < ApplicationController
  include SettingsNavigation
  include FormPageResponse

  before_action :admin_required!

  before_action :load_price, only: %i[edit update destroy]
  before_action :new_price, only: %i[new create]

  def index
    unless name.in?(Price.names.keys)
      redirect_to settings_prices_path(name: Price.names.keys.first)
      return
    end

    @prices = Price.list_for(name)
  end

  def new
  end

  def edit
  end

  def create = respond_to_save(@price, @price.save)

  def update = respond_to_save(@price, @price.update(permitted_params))

  def destroy
    @price.destroy!
    respond_with_list(notice: t('crud.deleted'))
  end

  private

  def list_stream
    turbo_stream.update('list', Price::List::Component.new(prices: Price.list_for(name), name:))
  end

  def default_list_path
    settings_prices_path(name:)
  end

  helper_method def title
    Price.human_enum_name(:name, name)
  end

  def permitted_params
    params.expect(
      price: %i[name starts_at amount_per_kwh amount_per_month note],
    )
  end

  helper_method def name
    params[:name] || @price&.name
  end

  def load_price
    @price = Price.find(params.expect(:id))
  end

  def new_price
    @price = Price.new(permitted_params)
  end
end
