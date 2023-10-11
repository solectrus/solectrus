module WithoutDetailedExceptions
  RSpec.configure { |config| config.include self, type: :request }

  def without_detailed_exceptions
    env_config = Rails.application.env_config
    original_show_exceptions = env_config['action_dispatch.show_exceptions']
    original_show_detailed_exceptions =
      env_config['action_dispatch.show_detailed_exceptions']
    env_config['action_dispatch.show_exceptions'] = :all
    env_config['action_dispatch.show_detailed_exceptions'] = false
    yield
  ensure
    env_config['action_dispatch.show_exceptions'] = original_show_exceptions
    env_config[
      'action_dispatch.show_detailed_exceptions'
    ] = original_show_detailed_exceptions
  end
end
