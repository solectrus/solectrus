class AddSettingSensorNames < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        sensor_names =
          (1..SensorConfig::CUSTOM_SENSOR_COUNT)
            .each_with_object({}) do |i, hash|
              hash['custom_power_%02d' % i] = Setting
                .where(var: format('custom_name_%02d', i))
                .first
                &.value
            end
            .compact

        # Save as hash
        Setting.sensor_names = sensor_names

        # Delete old single names
        Setting.where("var LIKE 'custom_name_%'").delete_all
      end

      dir.down { raise ActiveRecord::IrreversibleMigration }
    end
  end
end
