require_relative 'logger_manager'

module CalendarColorMCP
  module Loggable
    def logger
      @logger ||= LoggerManager.instance
    end
  end
end