class Settings::SystemsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  # The settings that are a part of MCP
  MCP_PARTS = %i[mcp_raw_data mcp_locations mcp_write].freeze
  private_constant :MCP_PARTS

  def edit
    # Without a summary, the rate is nil
    @summary_completion_rate = Summary.fresh_percentage(Timeframe.all) if Summary.exists?
  end

  def update
    value = permitted_params[:mcp_enabled]
    update_mcp_enabled(value) unless value.nil?
    MCP_PARTS.each do |part|
      part_value = permitted_params[part]
      update_mcp_part(part, part_value) unless part_value.nil?
    end

    # Redirect (instead of an inline flash) so the page re-renders and the MCP
    # endpoint hint appears or disappears after toggling the checkbox.
    redirect_to edit_settings_system_path, notice: t('crud.success')
  end

  private

  # Only sponsors may toggle MCP; ignore the param otherwise. Disabling MCP
  # rotates the OAuth signing secret, so every connected client is dropped and
  # must re-authorize - re-enabling does not bring old connections back. Nor
  # its parts, like the raw data: they hold only while MCP stays on, and MCP
  # switched on starts without them.
  def update_mcp_enabled(value)
    return unless ApplicationPolicy.mcp?

    enabling = value == '1'
    McpOauth.rotate_signing_secret! if Setting.mcp_enabled && !enabling
    MCP_PARTS.each { Setting.public_send(:"#{it}=", false) } unless Setting.mcp_enabled && enabling
    Setting.mcp_enabled = enabling
  end

  # A part of MCP needs MCP on (McpOauth.available?)
  def update_mcp_part(part, value)
    return unless McpOauth.available?

    Setting.public_send(:"#{part}=", value == '1')
  end

  helper_method def title
    t('settings.system.name')
  end

  def permitted_params
    params.expect(setting: [:mcp_enabled, *MCP_PARTS])
  end
end
