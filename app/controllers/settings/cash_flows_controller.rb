class Settings::CashFlowsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  before_action :load_cash_flow, only: %i[edit update destroy]
  before_action :new_cash_flow, only: %i[new create]

  # Optionally filtered by category and/or date range, so the amortization
  # table can drill down into the exact cash flows behind a cell (its category
  # within the PV year's date range).
  def index
    @cash_flows = filtered_cash_flows
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

  def filtered_cash_flows
    scope = CashFlow.ordered
    scope = scope.where(category: filter_categories) if filter_categories.any?
    scope = scope.where(date: ..filter_to) if filter_to
    scope = scope.where(date: filter_from..) if filter_from
    scope
  end

  # The categories the list is narrowed to. Accepts a single value or an array -
  # the amortization table drills into a whole category group (e.g. all
  # operating flows) at once. Intersecting with the enum keeps only known values,
  # so an unexpected param can't reach the query.
  helper_method def filter_categories
    @filter_categories ||=
      Array(params[:category]).map(&:to_s) & CashFlow.categories.keys
  end

  helper_method def filter_from
    @filter_from ||= parse_date(params[:from])
  end

  helper_method def filter_to
    @filter_to ||= parse_date(params[:to])
  end

  helper_method def filter_active?
    filter_categories.any? || filter_from || filter_to
  end

  def parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  rescue Date::Error
    nil
  end

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
