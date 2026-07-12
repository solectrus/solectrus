class Settings::CashFlowsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  before_action :load_cash_flow, only: %i[edit update destroy]
  before_action :new_cash_flow, only: %i[new create]
  before_action :restore_filter, only: %i[create update destroy]

  # Optionally filtered by category and/or date range, so the amortization
  # table can drill down into the exact cash flows behind a cell (its category
  # within the PV year's date range).
  def index
    @cash_flows = filtered_cash_flows
    remember_filter
  end

  # Set who may see the amortization calculation: everyone ('all'), admins only
  # ('admins'), or nobody ('none', which also removes the page from the
  # navigation). Exposing it to non-admins is a sponsor feature, so 'all' falls
  # back to admins-only without it.
  def visibility
    case params.dig(:setting, :amortization_visibility)
    when 'all'
      Setting.enable_amortization = true
      Setting.amortization_public = ApplicationPolicy.amortization?
    when 'admins'
      Setting.enable_amortization = true
      Setting.amortization_public = false
    when 'none'
      Setting.enable_amortization = false
    end

    # Renders visibility.turbo_stream.slim, which refreshes the flash and the
    # primary navigation so the icon appears/disappears without a page reload.
    flash.now[:notice] = t('crud.success')
  end

  def new
  end

  def edit
  end

  def create
    if @cash_flow.save
      render_filtered_list
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @cash_flow.update(permitted_params)
      render_filtered_list
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @cash_flow.destroy!
    render_filtered_list
  end

  private

  # Refresh the list straight from the mutating request (no Turbo broadcast, which
  # could not know the viewer's filter). The filter, remembered from the last
  # index render, stays applied so a new entry does not reveal the full list while
  # the filter is still shown.
  def render_filtered_list
    flash.now[:notice] = t('crud.success')
    render turbo_stream: [
             turbo_stream.update(
               'list',
               partial: 'settings/cash_flows/list',
               locals: {
                 cash_flows: filtered_cash_flows,
                 filter_categories:,
                 filter_from:,
                 filter_to:,
               },
             ),
             turbo_stream_update_flash,
           ]
  end

  # Persist the filter the index is currently showing, so a later mutation (which
  # carries no filter params of its own) can re-apply the same one.
  def remember_filter
    session[:cash_flow_filter] = {
      category: filter_categories,
      from: filter_from&.iso8601,
      to: filter_to&.iso8601,
    }
  end

  # Load the remembered filter into the ivars the filter helpers memoize, so a
  # mutation re-renders the list with the filter the user still sees.
  def restore_filter
    stored = session[:cash_flow_filter].to_h.with_indifferent_access
    @filter_categories =
      Array(stored[:category]).map(&:to_s) & CashFlow.categories.keys
    @filter_from = parse_date(stored[:from])
    @filter_to = parse_date(stored[:to])
  end

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
