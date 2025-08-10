require 'mcp'
require 'logger'
require 'fileutils'
require_relative 'token_manager'
require_relative 'google_calendar_auth_manager'
require_relative 'time_analyzer'
require_relative 'tools/analyze_calendar_tool'
require_relative 'tools/start_auth_tool'
require_relative 'tools/check_auth_status_tool'
require_relative 'tools/complete_auth_tool'

module CalendarColorMCP
  class Server
    def initialize
      # ログファイルの設定
      setup_logger

      log_info "Initializing CalendarColorMCP::Server..."

      # 必要な環境変数の検証
      validate_environment_variables

      @token_manager = TokenManager.instance
      @auth_manager = GoogleCalendarAuthManager.instance

      log_info "Creating MCP::Server with tools..."
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
        log_info "MCP::Server created successfully"
      rescue => e
        log_error "Error creating MCP::Server: #{e.message}"
        log_error "Backtrace: #{e.backtrace}"
        raise
      end
    end

    def run
      transport = MCP::Server::Transports::StdioTransport.new(@server)
      transport.open
    end

    def get_calendar_colors
      TimeAnalyzer::COLOR_NAMES.to_json
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

        STDERR.puts error_msg
        log_error error_msg
        raise error_msg
      end

        log_info "環境変数チェック完了: GOOGLE_CLIENT_ID=#{ENV['GOOGLE_CLIENT_ID'][0..10]}..."
        log_info "環境変数チェック完了: GOOGLE_CLIENT_SECRET=設定済み"
    end

    def setup_logger
      project_root = File.expand_path('../../..', __FILE__)
      log_dir = File.join(project_root, 'logs')
      FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
      log_file = File.join(log_dir, 'mcp-server-calendar-color-mcp.log')

      @logger = Logger.new(log_file, 'monthly')
      @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end

      STDERR.puts "ログファイル初期化完了: #{log_file}" if ENV['DEBUG']
    rescue => e
      STDERR.puts "ログファイル初期化エラー: #{e.message}"
    end

    def log_info(message)
      @logger&.info(message)
      STDERR.puts message if ENV['DEBUG']
    end

    def log_error(message)
      @logger&.error(message)
      STDERR.puts message
    end

    def log_debug(message)
      @logger&.debug(message)
      STDERR.puts message if ENV['DEBUG']
    end
  end
end
