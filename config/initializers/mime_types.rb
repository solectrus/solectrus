# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf

# TODO: Remove after updating gem "turbo-rails"
# https://github.com/hotwired/turbo-rails/pull/75
Mime::Type.register 'text/vnd.turbo-stream.html', :turbo_stream
