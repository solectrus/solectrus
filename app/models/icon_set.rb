# The icon path data the app renders from, read once from
# config/icons.generated.yml. See lib/icon_generator.rb for where that comes from,
# and IconHelper for the markup built out of it.
class IconSet
  Icon = Data.define(:name, :prefix, :width, :height, :path)
  public_constant :Icon

  class UnknownIcon < StandardError
  end

  ALL =
    YAML
      .load_file(Rails.root.join('config', 'icons.generated.yml'))
      .to_h do |name, data|
        [
          name,
          Icon.new(
            name:,
            prefix: data['prefix'],
            width: data['width'],
            height: data['height'],
            path: data['path'],
          ),
        ]
      end
      .freeze
  public_constant :ALL

  def self.find(name)
    ALL[name.to_s] ||
      raise(
        UnknownIcon,
        "No icon named #{name.inspect}. Add it to config/icons.yml and run `bin/rails icons:generate`.",
      )
  end

  def self.names
    ALL.keys
  end
end
