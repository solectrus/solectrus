# Not part of the Docker image: .dockerignore excludes this file.
#
# Simulates a HELIOS beside the application, so its menu item and the amber
# dot for a pending action can be seen in development.
#
# Development only. In test and production this file does nothing.
#
#   SIMULATE_HELIOS   running | action_required
#                     running         = HELIOS answers, nothing to do
#                     action_required = HELIOS answers and asks for the user
#                     Without it no HELIOS runs, as before.
#
# If a change seems to have no effect, run `bin/spring stop` first - a
# preloaded application keeps the environment it booted with.
return unless Rails.env.development?

module HeliosCheckSimulation
  STATES = %w[running action_required].freeze
  private_constant :STATES

  def version(cached: true)
    simulated ? Rails.configuration.x.git.commit_version : super
  end

  def action_required?
    simulated == 'action_required' || super
  end

  private

  def simulated
    ENV.fetch('SIMULATE_HELIOS', nil).presence_in(STATES)
  end
end

# HeliosCheck lives in app/ and is reloaded, so this runs on every reload.
Rails.application.config.to_prepare do
  HeliosCheck.prepend(HeliosCheckSimulation) unless HeliosCheck < HeliosCheckSimulation
end
