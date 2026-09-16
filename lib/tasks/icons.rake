namespace :icons do
  desc 'Generate config/icons.generated.yml from the @fortawesome packages'
  task generate: :environment do
    require 'icon_generator'

    generator = IconGenerator.new
    count = generator.call

    puts "Wrote #{count} icons to #{generator.target.relative_path_from(Rails.root)}"
  end
end
