module LlmTest
  # One `claude -p` run.
  #
  # The tests go through the Claude Code CLI rather than the Messages API, so
  # they are billed to the Claude subscription and not per token. What we give
  # up is the raw request: the CLI owns it. What we keep is everything the
  # tests actually read - every tool call with its arguments, the tokens each
  # turn cost, and the final answer - because --output-format stream-json
  # reports all of it.
  #
  # --system-prompt REPLACES Claude Code's own prompt, so a run starts as a
  # plain MCP client and not as a coding agent.
  class ClaudeCli
    SERVER = 'solectrus'.freeze
    public_constant :SERVER

    # No file, no shell, no web: a test must answer out of the MCP tools alone.
    ALLOWED_TOOLS = "mcp__#{SERVER}".freeze
    public_constant :ALLOWED_TOOLS

    ToolCall = Struct.new(:name, :arguments, :error)
    public_constant :ToolCall

    Result =
      Struct.new(
        :answer,
        :tool_calls,
        :input_tokens,
        :output_tokens,
        :context_tokens,
        :cost_usd,
        :rate_limit,
        :turns,
        :truncated,
      ) do
        def tool_names = tool_calls.map(&:name)
      end
    public_constant :Result

    def initialize(model:, socket: nil)
      @model = model
      @socket = socket
    end

    def call(prompt, system:)
      events = run(prompt, system)
      Parser.new(events).result
    end

    private

    def run(prompt, system)
      command = base_command + tool_arguments + ['--system-prompt', system, '--', prompt]
      events = []

      Open3.popen3(*command) do |stdin, stdout, stderr, wait|
        stdin.close
        stdout.each_line { |line| events << parse(line) }
        status = wait.value
        raise Error, stderr.read.presence || "claude exited with #{status.exitstatus}" unless status.success?
      end

      events.compact
    end

    # The stream carries one JSON object per line, and nothing else - but a
    # warning printed to stdout would break the run for no reason, so a line
    # that is not JSON is skipped.
    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def base_command
      [
        'claude',
        '--print',
        '--model',
        @model,
        '--output-format',
        'stream-json',
        '--verbose',
        '--permission-mode',
        'bypassPermissions',
        # No built-in tool at all. Without this a run has Claude Code's whole
        # toolbox next to ours, which not only lets it answer past the MCP
        # server but also pushes the tool count over the point where Claude
        # Code defers the tool list and searches it - so our descriptions would
        # reach the model through a search result instead of the prompt.
        '--tools',
        '',
      ]
    end

    # Without a socket there are no tools at all - that is how the judge runs.
    def tool_arguments
      return ['--strict-mcp-config'] unless @socket

      [
        '--strict-mcp-config',
        '--mcp-config',
        mcp_config,
        '--allowedTools',
        ALLOWED_TOOLS,
      ]
    end

    def mcp_config
      {
        mcpServers: {
          SERVER => {
            type: 'stdio',
            command: Rails.root.join('spec', 'llm_test', 'shim.rb').to_s,
            env: {
              'LLM_TEST_MCP_SOCKET' => @socket,
            },
          },
        },
      }.to_json
    end

    class Error < StandardError
    end

    # Reads the stream-json events: assistant turns carry the tool calls and
    # the usage, the final result event carries the answer.
    class Parser
      def initialize(events)
        @events = events
      end

      def result
        Result.new(
          answer: answer,
          tool_calls: tool_calls,
          input_tokens: tokens('input_tokens'),
          output_tokens: tokens('output_tokens'),
          context_tokens: context_tokens,
          cost_usd: final&.dig('total_cost_usd').to_f,
          rate_limit: rate_limit,
          turns: assistant_messages.size,
          truncated: final.nil? || final['is_error'] == true,
        )
      end

      private

      def final = @final ||= @events.find { _1['type'] == 'result' }

      def answer = final&.dig('result').to_s.strip

      def assistant_messages
        @assistant_messages ||=
          @events.filter_map { _1['message'] if _1['type'] == 'assistant' }
      end

      # An MCP tool is called mcp__<server>__<tool>; the test speaks of the
      # tool, so the prefix goes.
      def tool_calls
        blocks =
          assistant_messages.flat_map { Array(_1['content']) }
            .select { _1['type'] == 'tool_use' }

        blocks.map do |block|
          ToolCall.new(
            name: block['name'].to_s.sub(/\Amcp__#{SERVER}__/o, ''),
            arguments: block['input'] || {},
            error: errors[block['id']],
          )
        end
      end

      # A rejected call and WHY it was rejected. The reason separates the two
      # cases that look alike from outside: the server said no (a finding), or
      # the transport did (a broken run).
      def errors
        @errors ||=
          @events
            .filter_map { _1['message'] if _1['type'] == 'user' }
            .flat_map { Array(_1['content']) }
            .select { _1['type'] == 'tool_result' && _1['is_error'] }
            .to_h { [_1['tool_use_id'], reason(_1['content'])] }
      end

      def reason(content)
        text =
          case content
          when String then content
          else Array(content).filter_map { _1['text'] }.join(' ')
          end

        text.squish.presence&.slice(0, 200) || 'rejected'
      end

      # What a run actually costs a subscription: a share of the rolling usage
      # windows. The dollar figure the CLI reports is the API list price of the
      # same work and is billed to nobody here, so this is the number to watch.
      def rate_limit
        windows =
          @events
            .select { _1['type'] == 'rate_limit_event' }
            .filter_map { _1.dig('rate_limit_info', 'unifiedWindows') }
            .last

        return {} unless windows

        windows.transform_values { _1['utilization'] }
      end

      def tokens(key)
        assistant_messages.sum { _1.dig('usage', key).to_i }
      end

      # The largest context a turn was given, cached parts included. This is
      # the number our tool list and our descriptions move: what the model has
      # to read before it can answer.
      def context_tokens
        assistant_messages.map do |message|
          usage = message['usage'] || {}
          usage.values_at('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens')
               .sum(&:to_i)
        end.max.to_i
      end
    end
  end
end
