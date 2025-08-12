require 'singleton'
require 'logger'

module CalendarColorMCP
  class LoggerManager
    include Singleton

    LEVELS = {
      debug: Logger::DEBUG,
      info: Logger::INFO,
      warn: Logger::WARN,
      error: Logger::ERROR
    }.freeze

    def initialize
      setup_logger
    end

    def debug(message)
      log(:debug, message)
    end

    def info(message)
      log(:info, message)
    end

    def warn(message)
      log(:warn, message)
    end

    def error(message)
      log(:error, message)
    end

    # テスト用にログレベルを変更するためのアクセサ
    def logger
      @logger
    end

    private

    def setup_logger
      # stdoutベースのロガーを設定
      @logger = Logger.new(STDOUT)
      @logger.level = determine_log_level
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
    end

    def determine_log_level
      # テスト環境ではログを抑制
      if ENV['RSPEC_RUNNING'] == 'true' || ENV['RAILS_ENV'] == 'test' || ENV['RACK_ENV'] == 'test'
        Logger::FATAL
      else
        ENV['DEBUG'] == 'true' ? Logger::DEBUG : Logger::INFO
      end
    end

    def log(level, message)
      return unless should_log?(level)
      
      case level
      when :error
        # エラーはstderrに出力
        STDERR.puts formatted_message(level, message)
      else
        # その他はstdoutに出力
        @logger.send(level, message)
      end
    end

    def should_log?(level)
      LEVELS[level] >= @logger.level
    end

    def formatted_message(level, message)
      "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{level.upcase}: #{message}"
    end
  end
end