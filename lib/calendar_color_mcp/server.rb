require 'mcp'
require_relative 'loggable'
require_relative 'token_manager'
require_relative 'google_calendar_auth_manager'
require_relative 'tools/analyze_calendar_tool'
require_relative 'tools/start_auth_tool'
require_relative 'tools/check_auth_status_tool'
require_relative 'tools/complete_auth_tool'

module CalendarColorMCP
  class Server
    include Loggable
    
    def initialize
      logger.info "Initializing CalendarColorMCP::Server..."

      # 必要な環境変数の検証
      validate_environment_variables

      @token_manager = TokenManager.instance
      @auth_manager = GoogleCalendarAuthManager.instance

      logger.info "Creating MCP::Server with tools..."
      begin
        @server = MCP::Server.new(
          name: "calendar-color-analytics",
          version: "1.0.0",
          tools: [
            AnalyzeCalendarTool,
            StartAuthTool,
            CheckAuthStatusTool,
            CompleteAuthTool
          ],
          server_context: {
            token_manager: @token_manager,
            auth_manager: @auth_manager
          }
        )
        logger.info "MCP::Server created successfully"
      rescue => e
        logger.error "Error creating MCP::Server: #{e.message}"
        logger.error "Backtrace: #{e.backtrace}"
        raise
      end
    end

    # FIXME: ここで呼び出し失敗時のエラーハンドリングがあってもよさそう
    def run
      transport = MCP::Server::Transports::StdioTransport.new(@server)
      transport.open
    end

    private

    def validate_environment_variables
      missing_vars = []

      if ENV['GOOGLE_CLIENT_ID'].nil? || ENV['GOOGLE_CLIENT_ID'].empty?
        missing_vars << 'GOOGLE_CLIENT_ID'
      end

      if ENV['GOOGLE_CLIENT_SECRET'].nil? || ENV['GOOGLE_CLIENT_SECRET'].empty?
        missing_vars << 'GOOGLE_CLIENT_SECRET'
      end

      unless missing_vars.empty?
        error_msg = "必要な環境変数が設定されていません: #{missing_vars.join(', ')}\n"
        error_msg += ".env ファイルを確認し、以下の設定を行ってください:\n"
        missing_vars.each do |var|
          error_msg += "#{var}=your_#{var.downcase}\n"
        end

        logger.error error_msg
        raise error_msg
      end

        logger.info "環境変数チェック完了: GOOGLE_CLIENT_ID=#{ENV['GOOGLE_CLIENT_ID'][0..10]}..."
        logger.info "環境変数チェック完了: GOOGLE_CLIENT_SECRET=設定済み"
    end
  end
end
