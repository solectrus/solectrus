# The Git metadata of the build, which the base image writes to /etc/build-info
# as one NAME=value line each. The env vars of the same name are no substitute:
# a tool that recreates a container from the configuration of the old one
# carries over the values of the old image.
module BuildInfo
  PATH = '/etc/build-info'.freeze
  private_constant :PATH

  # Empty in a working copy.
  def self.read(path = PATH)
    return {} unless File.exist?(path)

    File.foreach(path, chomp: true).to_h { |line| line.split('=', 2) }
  end
end
