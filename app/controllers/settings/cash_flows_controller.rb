class Settings::CashFlowsController < ApplicationController
  include SettingsNavigation
  include FormPageResponse
  include FilteredList

  filters_with CashFlow::Filter

  before_action :admin_required!

  before_action :load_cash_flow, only: %i[edit update destroy]
  before_action :new_cash_flow, only: %i[new create]

  # Optionally filtered by category and/or date range (see FilteredList), so
  # the amortization table can drill down into the exact cash flows behind a
  # cell (its category within the PV year's date range).
  def index
    @cash_flows = filtered_cash_flows
  end

  # Set who may see the amortization calculation: everyone, admins only, or
  # nobody (which also removes the page from the navigation).
  def visibility
    AmortizationVisibility.level =
      params.dig(:setting, :amortization_visibility)

    # Renders visibility.turbo_stream.slim, which refreshes the flash and the
    # primary navigation so the icon appears/disappears without a page reload.
    flash.now[:notice] = t('crud.success')
  rescue ArgumentError
    # Which levels exist is the visibility object's rule, so an unknown one is
    # rejected there rather than being checked a second time here.
    head :unprocessable_content
  end

  def new
  end

  def edit
  end

  def create = respond_to_save(@cash_flow, @cash_flow.save)

  def update = respond_to_save(@cash_flow, @cash_flow.update(permitted_params))

  def destroy
    @cash_flow.destroy!
    respond_with_list(notice: t('crud.deleted'))
  end

  private

  # Refresh the list straight from the mutating request (no Turbo broadcast, which
  # could not know the viewer's filter). The filter of the list that opened the
  # form stays applied (see FilteredList), so a new entry does not reveal the full
  # list while the filter is still shown.
  def list_stream
    turbo_stream.update('list', CashFlow::List::Component.new(cash_flows: filtered_cash_flows, filter:))
  end

  def filtered_cash_flows = filter.apply(CashFlow.ordered)

  helper_method def title
    t('settings.cash_flows.name')
  end

  def permitted_params
    params.expect(cash_flow: %i[date amount note category])
  end

  def load_cash_flow
    @cash_flow = CashFlow.find(params.expect(:id))
  end

  # A new cash flow takes the category of the filter
  def new_cash_flow
    @cash_flow = CashFlow.new(date: Date.current, category: filter.category)
    @cash_flow.assign_attributes(permitted_params) if params[:cash_flow]
  end
end
