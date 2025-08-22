require 'mcp'
require_relative 'loggable'
require_relative 'interface_adapters/tools/analyze_calendar_tool'
require_relative 'interface_adapters/tools/start_auth_tool'
require_relative 'interface_adapters/tools/check_auth_status_tool'
require_relative 'interface_adapters/tools/complete_auth_tool'
require_relative 'infrastructure/repositories/google_calendar_repository'
require_relative 'infrastructure/repositories/token_repository'
require_relative 'infrastructure/services/configuration_service'
require_relative 'infrastructure/services/google_oauth_service'
require_relative 'application/use_cases/authenticate_user_use_case'
require_relative 'domain/entities/attendee'
require_relative 'domain/entities/organizer'

module CalendarColorMCP
  class Server
    include Loggable

    def initialize
      logger.info "Initializing CalendarColorMCP::Server..."

      # Infrastructure層の設定サービスによる環境変数検証
      begin
        @config_service = Infrastructure::ConfigurationService.instance
        logger.info "環境変数チェック完了: GOOGLE_CLIENT_ID=#{@config_service.google_client_id[0..10]}..."
        logger.info "環境変数チェック完了: GOOGLE_CLIENT_SECRET=設定済み"
      rescue Infrastructure::ConfigurationError => e
        logger.error e.message
        raise e.message
      end

      @oauth_service = Infrastructure::GoogleOAuthService.new
      @token_repository = Infrastructure::TokenRepository.instance
      @calendar_repository = Infrastructure::GoogleCalendarRepositoryLogDecorator.new(
        Infrastructure::GoogleCalendarRepository.new
      )

      logger.info "Creating MCP::Server with tools..."
      begin
        @server = MCP::Server.new(
          name: "calendar-color-analytics",
          version: "1.0.0",
          tools: [
            InterfaceAdapters::AnalyzeCalendarTool,
            InterfaceAdapters::StartAuthTool,
            InterfaceAdapters::CheckAuthStatusTool,
            InterfaceAdapters::CompleteAuthTool
          ],
          server_context: {
            oauth_service: @oauth_service,
            token_repository: @token_repository,
            calendar_repository: @calendar_repository
          }
        )
        logger.info "MCP::Server created successfully"
      rescue => e
        logger.error "Error creating MCP::Server: #{e.message}"
        logger.error "Backtrace: #{e.backtrace}"
        raise
      end
    end

    def run
      logger.info "Starting MCP server transport..."
      transport = MCP::Server::Transports::StdioTransport.new(@server)
      transport.open
    rescue => e
      logger.error "Server startup failed: #{e.message}"
      logger.error "Backtrace: #{e.backtrace&.first(5)&.join(', ')}"
      raise "Failed to start MCP server: #{e.message}"
    end
  end
end
