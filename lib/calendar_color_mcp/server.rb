require 'mcp'
require_relative 'user_manager'
require_relative 'auth_manager'
require_relative 'time_analyzer'
require_relative 'tools/analyze_calendar_tool'
require_relative 'tools/start_auth_tool'
require_relative 'tools/check_auth_status_tool'

module CalendarColorMCP
  class Server
    def initialize
      @user_manager = UserManager.new
      @auth_manager = AuthManager.new

      @server = MCP::Server.new(
        name: "calendar-color-analytics",
        version: "1.0.0",
        tools: [
          AnalyzeCalendarTool,
          StartAuthTool,
          CheckAuthStatusTool
        ],
        server_context: {
          user_manager: @user_manager,
          auth_manager: @auth_manager
        }
      )
    end

    def run
      transport = MCP::Server::Transports::StdioTransport.new(@server)
      transport.open
    end

    # リソースハンドラー（将来的に追加予定）
    def get_users_auth_status
      users = @user_manager.list_users
      auth_status = users.map do |user_id|
        {
          user_id: user_id,
          authenticated: @user_manager.authenticated?(user_id),
          last_auth: @user_manager.last_auth_time(user_id)
        }
      end

      {
        total_users: users.count,
        users: auth_status
      }.to_json
    end

    def get_calendar_colors
      TimeAnalyzer::COLOR_NAMES.to_json
    end
  end
end
