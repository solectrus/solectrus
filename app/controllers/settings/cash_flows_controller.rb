class Settings::CashFlowsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  before_action :load_cash_flow, only: %i[edit update destroy]
  before_action :new_cash_flow, only: %i[new create]

  def index
    @cash_flows = CashFlow.ordered
  end

  # Toggle whether non-admins may see the amortization calculation. Only
  # meaningful with the sponsor feature, so ignore the param otherwise.
  def visibility
    if ApplicationPolicy.amortization?
      Setting.amortization_public =
        params.dig(:setting, :amortization_public) == '1'
    end

    respond_with_flash notice: t('crud.success')
  end

  def new
  end

  def edit
  end

  def create
    if @cash_flow.save
      respond_with_flash notice: t('crud.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @cash_flow.update(permitted_params)
      respond_with_flash notice: t('crud.success')
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @cash_flow.destroy!
    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    t('settings.cash_flows.name')
  end

  def permitted_params
    params.expect(cash_flow: %i[date amount note category])
  end

  def load_cash_flow
    @cash_flow = CashFlow.find(params.expect(:id))
  end

  def new_cash_flow
    @cash_flow =
      if params[:cash_flow]
        CashFlow.new(permitted_params)
      else
        CashFlow.new(date: Date.current)
      end
  end
end
