if Rails.env.test?
  # Disable auto build in test environment.
  # Assets are pre-built via ci.rb or `yarn vite build --mode test` instead.
  RailsVite.config.auto_build = false
end
