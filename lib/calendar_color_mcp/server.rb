require 'mcp'
require_relative 'loggable'
require_relative 'token_manager'
require_relative 'google_calendar_auth_manager'
require_relative 'interface_adapters/tools/analyze_calendar_tool'
require_relative 'interface_adapters/tools/start_auth_tool'
require_relative 'interface_adapters/tools/check_auth_status_tool'
require_relative 'interface_adapters/tools/complete_auth_tool'
require_relative 'infrastructure/repositories/google_calendar_repository'
require_relative 'domain/services/event_filter_service'
require_relative 'time_analyzer'

module CalendarColorMCP
  class Server
    include Loggable

    def initialize
      logger.info "Initializing CalendarColorMCP::Server..."

      # 必要な環境変数の検証
      # TODO: infra層のやつ買っていいのでは？
      validate_environment_variables

      @token_manager = TokenManager.instance
      @auth_manager = GoogleCalendarAuthManager.instance
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
            token_manager: @token_manager,
            auth_manager: @auth_manager,
            calendar_repository: @calendar_repository,
            filter_service: Domain::EventFilterService.new, # TODO: これもinfra層のやつにしていいかも
            analyzer_service: CalendarColorMCP::TimeAnalyzer.new # TODO: これもinfra層のやつにしていいかも
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
