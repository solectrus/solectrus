desc 'List routes like "rails routes", but exclude models and controllers from gems'
# https://github.com/ctran/annotate_models/issues/842

task routes: :environment do
  # :nocov:
  Rails.application.eager_load!
  models = ApplicationRecord.descendants.map(&:name).join('|').downcase
  controllers = ApplicationController.descendants.map(&:name)
  controllers =
    (controllers.map { |controller| controller[0..-11].downcase }).join('|')
  if models
    puts `bundle exec rails routes -g "#{models}|#{controllers}"`
  else
    puts `bundle exec rails routes -g "#{controllers}"`
  end
  # :nocov:
end
