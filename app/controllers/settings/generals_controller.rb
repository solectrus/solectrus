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
        # Only sponsors may toggle MCP; ignore the param otherwise.
        Setting.mcp_enabled = value == '1' if ApplicationPolicy.mcp?
      else
        Setting.public_send(:"#{key}=", value.strip)
      end
    end

    Setting.ensure_mcp_token! if ApplicationPolicy.mcp? && Setting.mcp_enabled

    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.expect(setting: %i[plant_name operator_name mcp_enabled])
  end
end
