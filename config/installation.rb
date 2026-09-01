# Checks the installation at boot.
#
# Loaded by path from config/application.rb, before the first file in
# config/initializers. Keep it there, it does not belong in an initializer.
module Installation
  class Invalid < StandardError; end

  def self.verify!(root)
    mounted = foreign_mounts(root, mount_points).first
    raise Invalid, "#{mounted} is mounted" if mounted
  end

  # Nothing of this installation mounts anything into the application, and no
  # place in it needs a mount.
  #
  # Apart so a test can pass the mount table of a real container.
  def self.foreign_mounts(root, mount_points)
    prefix = "#{root}/"

    mount_points.select { |path| path == root || path.start_with?(prefix) }
  end

  # Field 5 of every line is the mount point. Absent outside Linux, and then
  # there is nothing to say.
  def self.mount_points
    File.foreach('/proc/self/mountinfo').filter_map { |line| line.split[4] }
  rescue SystemCallError
    []
  end
end

Installation.freeze
