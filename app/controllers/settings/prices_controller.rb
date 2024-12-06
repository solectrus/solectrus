class Settings::PricesController < ApplicationController
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

  def create
    if @price.save
      respond_with_flash notice: t('crud.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @price.update(permitted_params)
      respond_with_flash notice: t('crud.success')
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @price.destroy!
    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    Price.human_enum_name(:name, name)
  end

  def permitted_params
    params.require(:price).permit(:name, :starts_at, :value, :note)
  end

  helper_method def name
    params[:name] || @price&.name
  end

  helper_method def nav_items
    [
      {
        name: t('settings.general.name'),
        href: settings_general_path,
        current: false,
      },
      {
        name: Price.human_enum_name(:name, :electricity),
        href: settings_prices_path(name: 'electricity'),
        current: name == 'electricity',
      },
      {
        name: Price.human_enum_name(:name, :feed_in),
        href: settings_prices_path(name: 'feed_in'),
        current: name == 'feed_in',
      },
    ]
  end

  def load_price
    @price = Price.find(params[:id])
  end

  def new_price
    @price = Price.new(permitted_params)
  end
end
