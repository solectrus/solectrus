# Redirect deprecated routes from v0.14.5 or older
# TODO: Remove this file in a future release

module DeprecatedRoutesRedirect
  def self.draw(mapper)
    mapper.instance_eval do
      {
        'bat_power' => 'battery_power',
        'bat_fuel_charge' => 'battery_soc',
        'wallbox_charge_power' => 'wallbox_power',
      }.each do |old, new|
        get "/#{old}", to: redirect("/#{new}")
        get "/#{old}/:timeframe", to: redirect("/#{new}/%{timeframe}")
      end

      {
        'wallbox_charge_power' => 'wallbox_power',
        'bat_power_minus' => 'battery_charging_power',
        'bat_power_plus' => 'battery_discharging_power',
        'grid_power_minus' => 'grid_export_power',
        'grid_power_plus' => 'grid_import_power',
      }.each do |old, new|
        get "/top10/:period/#{old}/:calc/:sort",
            to: redirect("/top10/%{period}/#{new}/%{calc}/%{sort}")
      end
    end
  end
end
