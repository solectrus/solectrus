describe 'Rack compression' do
  %w[gzip deflate,gzip gzip,deflate].each do |accepted_encoding|
    it "compresses with gzip when accepting #{accepted_encoding.inspect}" do
      get root_path, headers: { HTTP_ACCEPT_ENCODING: accepted_encoding }

      expect(response.headers['Content-Encoding']).to eq('gzip')
    end
  end

  %w[
    br
    br,gzip
    gzip,br
    gzip,deflate,br
    gzip,deflate,br,zstd
  ].each do |accepted_encoding|
    it "compresses with brotli when accepting #{accepted_encoding.inspect}" do
      get root_path, headers: { HTTP_ACCEPT_ENCODING: accepted_encoding }

      expect(response.headers['Content-Encoding']).to eq('br')
    end
  end

  ['identity', nil].each do |accepted_encoding|
    it "does not compress when accepting #{accepted_encoding.inspect}" do
      get root_path, headers: {}

      expect(response.headers).not_to have_key('Content-Encoding')
    end
  end
end
