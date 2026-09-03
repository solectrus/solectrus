#!/usr/bin/env ruby
# frozen_string_literal: true

# The stdio MCP server the `claude` CLI starts for one test run.
#
# It boots nothing: every JSON-RPC line goes to the UNIX socket of the running
# harness process, which holds the booted Rails app and the fixture (see
# llm_test/harness/bridge.rb). That keeps a run's startup at milliseconds instead
# of a Rails boot.
require 'socket'

# A command line tool, not a spec: stdout is the MCP transport.
# rubocop:disable RSpec/Output

socket = UNIXSocket.new(ENV.fetch('LLM_TEST_MCP_SOCKET')) # rubocop:disable Style/HashLookupMethod

$stdout.sync = true

while (line = $stdin.gets)
  socket.write(line)
  response = socket.gets
  # An empty line means "notification, no answer" - see LlmTest::Bridge.
  $stdout.write(response) if response && !response.strip.empty?
end
# rubocop:enable RSpec/Output
