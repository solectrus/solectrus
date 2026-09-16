# Preloads the web font that the stylesheet pulls in.
#
# The browser finds the @font-face rule only after it has downloaded and parsed
# application.css, so the font starts one round trip late. `font-display: swap`
# keeps the text visible through that gap, which makes this a matter of how soon
# the text settles into its real font, not of whether it appears at all.
#
# It renders for a built manifest alone. The dev server serves an unbundled
# stylesheet from a path the manifest does not carry, so there is no round trip
# to save there and no hashed file to point at.
class FontPreload::Component < ViewComponent::Base
  # For `vite_asset_url`, which puts the asset prefix and any asset host in
  # front of a manifest path. ViewComponent does not carry the Vite helpers by
  # itself, and reimplementing that prefixing here would duplicate the gem.
  include RailsVite::TagHelper

  # The key of the font in the Vite manifest, which is the import in
  # application.css resolved from the project root. It goes to the manifest
  # directly, because `vite_asset_path` prefixes the source directory and the
  # font sits outside it.
  FONT =
    'node_modules/@fontsource-variable/inter/files/inter-latin-wght-normal.woff2'.freeze
  public_constant :FONT

  def render?
    path.present?
  end

  # `crossorigin` is not optional, even though the font is same-origin: a font
  # is always fetched in CORS mode, and a preload without it does not match that
  # fetch. The browser would download the font twice.
  def call
    tag.link(
      rel: 'preload',
      href: path,
      as: 'font',
      type: 'font/woff2',
      crossorigin: 'anonymous',
    )
  end

  private

  def path
    return if RailsVite.config.dev_server_running?

    @path ||= vite_asset_url(RailsVite.manifest.path_for(FONT))
  rescue StandardError
    # A build without the font leaves the page working, only without the hint.
    nil
  end
end
