class Settings::PricesController < ApplicationController
  include SettingsNavigation

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
      render_list
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @price.update(permitted_params)
      render_list
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @price.destroy!
    render_list
  end

  private

  # Refresh the list straight from the mutating request.
  def render_list
    flash.now[:notice] = t('crud.success')
    render turbo_stream: [
             turbo_stream.update(
               'list',
               partial: 'settings/prices/list',
               locals: {
                 prices: Price.list_for(name),
                 name:,
               },
             ),
             turbo_stream_update_flash,
           ]
  end

  helper_method def title
    Price.human_enum_name(:name, name)
  end

  def permitted_params
    params.expect(price: %i[name starts_at value note])
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
