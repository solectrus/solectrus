class Settings::GeneralsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    @summary_completion_rate = Summary.fresh_percentage(Timeframe.all)
  end

  def update
    permitted_params.each do |key, value|
      next if value.nil?

      if key == 'mcp_enabled'
        update_mcp_enabled(value)
      else
        Setting.public_send(:"#{key}=", value.strip)
      end
    end

    respond_with_flash notice: t('crud.success')
  end

  private

  # Only sponsors may toggle MCP; ignore the param otherwise. Disabling MCP
  # rotates the OAuth signing secret, so every connected client is dropped and
  # must re-authorize - re-enabling does not bring old connections back.
  def update_mcp_enabled(value)
    return unless ApplicationPolicy.mcp?

    enabling = value == '1'
    McpOauth.rotate_signing_secret! if Setting.mcp_enabled && !enabling
    Setting.mcp_enabled = enabling
  end

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.expect(setting: %i[plant_name operator_name mcp_enabled])
  end
end
