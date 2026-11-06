class Settings::SystemsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    # Without a summary, the rate is nil
    @summary_completion_rate = Summary.fresh_percentage(Timeframe.all) if Summary.exists?
  end

  def update
    value = permitted_params[:mcp_enabled]
    update_mcp_enabled(value) unless value.nil?
    raw_data = permitted_params[:mcp_raw_data]
    update_mcp_raw_data(raw_data) unless raw_data.nil?

    # Redirect (instead of an inline flash) so the page re-renders and the MCP
    # endpoint hint appears or disappears after toggling the checkbox.
    redirect_to edit_settings_system_path, notice: t('crud.success')
  end

  private

  # Only sponsors may toggle MCP; ignore the param otherwise. Disabling MCP
  # rotates the OAuth signing secret, so every connected client is dropped and
  # must re-authorize - re-enabling does not bring old connections back. Nor
  # the raw data: it holds only while MCP stays on, and MCP switched on
  # starts without it.
  def update_mcp_enabled(value)
    return unless ApplicationPolicy.mcp?

    enabling = value == '1'
    McpOauth.rotate_signing_secret! if Setting.mcp_enabled && !enabling
    Setting.mcp_raw_data = false unless Setting.mcp_enabled && enabling
    Setting.mcp_enabled = enabling
  end

  # Raw data is a part of MCP, so it needs MCP on (McpOauth.available?)
  def update_mcp_raw_data(value)
    return unless McpOauth.available?

    Setting.mcp_raw_data = value == '1'
  end

  helper_method def title
    t('settings.system.name')
  end

  def permitted_params
    params.expect(setting: %i[mcp_enabled mcp_raw_data])
  end
end
