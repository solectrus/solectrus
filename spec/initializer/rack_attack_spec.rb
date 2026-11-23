describe 'Rack::Attack configuration' do # rubocop:disable RSpec/DescribeClass
  # RemoteIp has already run when Rack::Attack sees the request, and left the
  # client address in the env. REMOTE_ADDR is the trusted proxy in front.
  let(:env) do
    Rack::MockRequest.env_for(
      path,
      method: 'POST',
      'REMOTE_ADDR' => '198.51.100.1',
      'action_dispatch.remote_ip' => '203.0.113.7',
    )
  end
  let(:request) { Rack::Attack::Request.new(env) }

  describe 'Request#remote_ip' do
    let(:path) { '/login' }

    it 'is the client address found by ActionDispatch::RemoteIp' do
      expect(request.remote_ip).to eq('203.0.113.7')
    end
  end

  {
    'logins/ip' => '/login',
    'lockup/ip' => '/lockup/unlock',
    'mcp/ip' => '/mcp',
    'oauth-authorize/ip' => '/oauth/authorize',
    'oauth-token/ip' => '/oauth/token',
    'req/ip' => '/settings',
  }.each do |name, throttled_path|
    describe "throttle #{name}" do
      let(:path) { throttled_path }

      it 'counts per client address' do
        expect(Rack::Attack.throttles[name].block.call(request)).to eq('203.0.113.7')
      end
    end
  end
end
