VCR.configure do |config|
  config.hook_into :webmock
  config.cassette_library_dir = 'spec/support/cassettes'
  config.configure_rspec_metadata!

  record_mode = ENV['VCR'] ? ENV['VCR'].to_sym : :once
  config.default_cassette_options = {
    record: record_mode,
    allow_playback_repeats: true,
  }

  config.ignore_localhost = true

  # Store response bodies as readable text instead of base64. WebMock hands us
  # ASCII-8BIT (binary) bodies, which VCR serializes as `!binary` base64 blobs.
  # Re-encode to UTF-8 when the bytes are valid UTF-8 so cassettes stay diffable.
  config.before_record do |interaction|
    body = interaction.response.body
    if body.encoding == Encoding::ASCII_8BIT
      utf8 = body.dup.force_encoding(Encoding::UTF_8)
      body.force_encoding(Encoding::UTF_8) if utf8.valid_encoding?
    end
  end
end
