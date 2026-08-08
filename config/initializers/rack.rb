# Remove 'x-runtime' header
Rails.application.config.middleware.delete(Rack::Runtime)

# Add content_type for some file extension not included in the
# list of defaults: https://github.com/rack/rack/blob/master/lib/rack/mime.rb
Rack::Mime::MIME_TYPES['.webmanifest'] = 'application/manifest+json'

# Enable gzip and brotli compression
Rails.application.config.middleware.insert(0, Rack::Brotli)
Rails.application.config.middleware.insert(0, Rack::Deflater)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # The MCP endpoint and its OAuth/discovery documents are called cross-origin
  # by browser-based AI clients (e.g. claude.ai web), so they need permissive
  # CORS regardless of app_host. Auth is via bearer token + PKCE (no cookies),
  # so allowing any origin carries no CSRF risk. WWW-Authenticate is exposed so
  # the client can discover the authorization server from the 401 response.
  allow do
    origins '*'
    resource '/mcp',
             headers: :any,
             methods: %i[post options],
             expose: %w[WWW-Authenticate]
    resource '/oauth/*', headers: :any, methods: %i[post options]
    resource '/.well-known/oauth-protected-resource',
             headers: :any,
             methods: %i[get options]
    # RFC 9728 inserts the resource path after the well-known segment, so a
    # client discovering the metadata for /mcp asks here (see config/routes.rb).
    # Rack::Cors matches a path without a wildcard exactly, so the rule above
    # does not cover it and the browser drops the answer it gets.
    resource '/.well-known/oauth-protected-resource/mcp',
             headers: :any,
             methods: %i[get options]
    resource '/.well-known/oauth-authorization-server',
             headers: :any,
             methods: %i[get options]
  end

  # Everything else (assets, app endpoints): only from the app's own host.
  if Rails.application.config.x.app_host
    allow do
      origins Rails.application.config.x.app_host
      resource '*', headers: :any, methods: %i[get post options]
    end
  end
end

# CDN: Allow Cloudfront for assets only
if Rails.application.config.x.app_host && Rails.application.config.asset_host
  require './app/middleware/cloudfront_denier'

  Rails.application.config.middleware.use CloudfrontDenier,
                  target: "https://#{Rails.application.config.x.app_host}"
end
