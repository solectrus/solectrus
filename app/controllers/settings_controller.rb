class SettingsController < ApplicationController
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

  helper_method def nav_items
    [
      { name: t('settings.general.name'), href: settings_path, current: true },
      {
        name: Price.human_enum_name(:name, :electricity),
        href: prices_path(name: 'electricity'),
        current: false,
      },
      {
        name: Price.human_enum_name(:name, :feed_in),
        href: prices_path(name: 'feed_in'),
        current: false,
      },
    ]
  end
end
