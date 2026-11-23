# The files that Vite builds carry a digest in their name, so a file never
# changes under its name. A browser and a CDN may keep them for a year without
# asking again. The other files in public/ keep their name across releases and
# get the shorter default of config.public_file_server.headers.
class ImmutableAssets
  CACHE_CONTROL =
    "public, s-maxage=#{1.year.to_i}, max-age=#{1.year.to_i}, immutable".freeze
  private_constant :CACHE_CONTROL

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    # A range request (206) gets a part of the same immutable file
    if [200, 206].include?(status) && asset?(env['PATH_INFO'])
      headers['cache-control'] = CACHE_CONTROL
    end

    [status, headers, body]
  end

  private

  # Escapes and dot segments resolved, as ActionDispatch::Static resolves them
  # to find the file. Vite puts the built files into its directory assets/.
  def asset?(path_info)
    Rack::Utils
      .clean_path_info(Rack::Utils.unescape_path(path_info))
      .start_with?("#{RailsVite.config.asset_prefix}/assets/")
  end
end
