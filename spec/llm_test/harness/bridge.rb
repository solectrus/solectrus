module LlmTest
  # Serves our own MCP server to the `claude` CLI, over a UNIX socket.
  #
  # Claude Code speaks stdio to an MCP server, and stdio means a new process
  # per run - a Rails boot each time. So the Rails side lives here, in the
  # harness process that is booted and seeded once, and llm_test/harness/shim.rb
  # is the tiny stdio client that pipes one run's traffic to this socket.
  #
  # What crosses the socket is what McpController hands to the transport, and
  # what comes back is McpServer::Server's own answer - so a run sees the
  # shipped tool list and the shipped descriptions, byte for byte, without an
  # HTTP server or an OAuth token in the way.
  class Bridge
    def initialize(path)
      @path = path
      @server = McpServer::Server.build
    end

    def start
      FileUtils.rm_f(@path)
      @socket = UNIXServer.new(@path)
      @thread = Thread.new { accept_loop } # rubocop:disable ThreadSafety/NewThread
      self
    end

    def stop
      @thread&.kill
      @socket&.close
      FileUtils.rm_f(@path)
    end

    private

    def accept_loop
      loop do
        connection = @socket.accept
        Thread.new { serve(connection) } # rubocop:disable ThreadSafety/NewThread
      end
    rescue IOError, Errno::EBADF
      nil # socket closed, we are shutting down
    end

    def serve(connection)
      while (line = connection.gets)
        # A notification has no response; the empty line keeps the shim in
        # step, which reads exactly one line per line it writes.
        connection.write("#{handle(line)}\n")
      end
    ensure
      connection.close
    end

    # The executor gives the thread a database connection and the usual Rails
    # per-request setup, which the tools need as much here as in a controller.
    def handle(line)
      Rails.application.executor.wrap { @server.handle_json(line.strip) }
    rescue StandardError => e
      warn "MCP bridge: #{e.class} #{e.message}"
      nil
    end
  end
end
