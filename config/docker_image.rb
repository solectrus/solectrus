# Holds the name the Docker image runs under to the one it was built for:
# production.
#
# This raises a cost. It does not close a door: a Docker image that is changed
# can say anything about itself. What this buys is that nothing cheaper than
# changing it works, and a change shows in AppDigest.
#
# Loaded by path from config/boot.rb, before the first gem and long before the
# first file in config/initializers. Keep it there, it does not belong in an
# initializer.
module DockerImage
  class Invalid < StandardError; end

  # The one environment the Docker image is built for. It carries the
  # configuration of that environment alone, and the name that starts it has to
  # be this one.
  ENVIRONMENT = 'production'.freeze
  private_constant :ENVIRONMENT

  # The file the build writes into the root of the Docker image, see the
  # Dockerfile. A working copy carries every file of the repository and this one
  # is in none of them, so a container that holds a working copy is not one.
  MARKER = '.image'.freeze
  private_constant :MARKER

  def self.built?(root)
    File.exist?(File.join(root, MARKER))
  end

  # Read once, at load. What a process runs on does not change while it runs.
  #
  # Public, because config/boot.rb reads it before the first gem is loaded.
  BUILT = built?(File.expand_path('..', __dir__))
  public_constant :BUILT

  # The Docker image carries the configuration of the one environment it is
  # built for. A working copy carries the configuration of every environment it
  # runs.
  def self.configured_environment?(config_dir, env)
    File.exist?(File.join(config_dir, 'environments', "#{env}.rb"))
  end

  # Two things must hold for the name that started the application.
  #
  # The Docker image runs production and no other environment, whatever name it
  # is started with. This is the one place that says so, and it says it by
  # stopping the application. Everywhere else reads Rails.env as it always did,
  # and reads it correctly because of this.
  #
  # And the name needs a configuration file of its own, in the Docker image and
  # in a working copy alike. Rails starts without one, but it starts half
  # configured: eager_load stays nil, Rails prints a warning about it, and
  # caching and logging fall back to the defaults of no environment at all.
  def self.verify_environment!(config_dir, env, built = BUILT)
    if built && env != ENVIRONMENT
      raise Invalid, "the Docker image runs #{ENVIRONMENT}, not #{env}"
    end

    return if configured_environment?(config_dir, env)

    raise Invalid, "no configuration for RAILS_ENV=#{env}"
  end
end

DockerImage.freeze
