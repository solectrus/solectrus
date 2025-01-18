class Settings::GeneralsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    @summary_completion_rate = Summary.fresh_percentage(Timeframe.all)
  end

  def update
    permitted_params.each_key do |key|
      unless permitted_params[key].nil?
        Setting.public_send(:"#{key}=", permitted_params[key].strip)
      end
    end

    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.expect(setting: %i[plant_name operator_name opportunity_costs])
  end
end
