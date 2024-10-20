class ThemeConfig
  # Allow global access to the sensor configuration via Rails.application.config
  def self.setup(env)
    Rails.application.config.theme = ThemeConfig.new(env)
  end

  def self.x
    Rails.application.config.theme
  end

  class Error < RuntimeError
  end

  def initialize(env)
    @theme = env['UI_THEME']
    return if @theme.in?(['light', 'dark', nil])

    raise Error, 'UI_THEME must be one of "light" or "dark"'
  end

  LIGHT_COLOR = '#a5b4fc'.freeze
  DARK_COLOR = '#1e1b4b'.freeze
  private_constant :LIGHT_COLOR
  private_constant :DARK_COLOR

  def color
    return LIGHT_COLOR unless ApplicationPolicy.themes?

    case @theme
    when 'light', nil
      LIGHT_COLOR
    when 'dark'
      DARK_COLOR
    end
  end

  def static?
    return false unless ApplicationPolicy.themes?

    @theme.present?
  end

  def html_class
    return false unless ApplicationPolicy.themes?

    @theme
  end
end
