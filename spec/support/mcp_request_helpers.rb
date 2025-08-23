require 'open3'
require 'json'

module MCPRequestHelpers
  def execute_mcp_requests(requests, timeout = 5, server_command = './bin/calendar-color-mcp')
    requests_json = requests.map(&:to_json).join("\n")

    # テスト実行時はログを抑制する環境変数を設定
    env = { 
      'RSPEC_RUNNING' => 'true',
      'GOOGLE_CLIENT_ID' => ENV['GOOGLE_CLIENT_ID'] || 'test-client-id-default',
      'GOOGLE_CLIENT_SECRET' => ENV['GOOGLE_CLIENT_SECRET'] || 'test-client-secret-default'
    }
    
    stdout, stderr, _status = Open3.capture3(
      env,
      "echo '#{requests_json}' | timeout #{timeout} #{server_command}"
    )

    begin
      # Handle JSON parsing with detailed error info for test debugging
      # server execution may produce unexpected output that needs investigation
      responses = stdout.strip.split("\n").map { |line| JSON.parse(line) }
    rescue JSON::ParserError => e
      puts "stdout: #{stdout}"
      puts "stderr: #{stderr}"
      raise "Failed to parse JSON responses: #{e.message}"
    end

    responses
  end

  def initialize_request(id = 0)
    {
      method: "initialize",
      params: {
        protocolVersion: "2025-06-18",
        capabilities: {},
        clientInfo: { name: "claude-ai", version: "0.1.0" }
      },
      jsonrpc: "2.0",
      id: id
    }
  end

  def tools_list_request(id = 1)
    {
      jsonrpc: "2.0",
      id: id,
      method: "tools/list",
      params: {}
    }
  end

  def check_auth_status_request(id = 1)
    {
      method: "tools/call",
      params: {
        name: "check_auth_status_tool",
        arguments: {}
      },
      jsonrpc: "2.0",
      id: id
    }
  end

  def start_auth_request(id = 2)
    {
      method: "tools/call",
      params: {
        name: "start_auth_tool",
        arguments: {}
      },
      jsonrpc: "2.0",
      id: id
    }
  end

  def complete_auth_request(auth_code, id = 3)
    {
      method: "tools/call",
      params: {
        name: "complete_auth_tool",
        arguments: {
          auth_code: auth_code
        }
      },
      jsonrpc: "2.0",
      id: id
    }
  end

  def analyze_calendar_request(start_date, end_date, id = 2, options = {})
    arguments = {
      start_date: start_date,
      end_date: end_date
    }
    arguments[:include_colors] = options[:include_colors] if options[:include_colors]
    arguments[:exclude_colors] = options[:exclude_colors] if options[:exclude_colors]

    {
      method: "tools/call",
      params: {
        name: "analyze_calendar_tool",
        arguments: arguments
      },
      jsonrpc: "2.0",
      id: id
    }
  end
end
