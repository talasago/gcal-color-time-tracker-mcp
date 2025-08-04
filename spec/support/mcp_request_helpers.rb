module MCPRequestHelpers
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