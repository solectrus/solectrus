# Read before the first gem, because config/application.rb asks it about the
# name this process was started with, and Rails reads that name early.
require_relative 'docker_image'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Bootsnap writes compiled code beside the application and runs what it finds
# there on the next boot. A container throws that cache away with every start,
# so the Docker image pays for writing it and never reads it. It boots twice
# per start and pays about 0.3 seconds without it.
#
# Development and test keep the cache. They boot far more often, and the gem is
# in their groups alone, so the Docker image does not even bundle it. The build
# is neither one: it carries no mark yet, and it bundles what the Docker image
# gets, so no bootsnap is there to load.
begin
  require 'bootsnap/setup' unless DockerImage::BUILT
rescue LoadError
  nil
end
