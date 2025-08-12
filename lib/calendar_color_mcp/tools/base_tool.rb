require 'mcp'
require_relative '../loggable'
require_relative '../logger_manager'

module CalendarColorMCP
  class BaseTool < MCP::Tool
    include Loggable
    
    class << self
      protected
      
      def logger
        @logger ||= LoggerManager.instance
      end

      def extract_auth_manager(context)
        server_context = context[:server_context]
        auth_manager = server_context&.dig(:auth_manager)

        if auth_manager.nil?
          raise ArgumentError, "認証マネージャーが利用できません"
        end

        auth_manager
      end

      # TODO: もしかしたらこっちもbuilderパターンの方が良いのかもしれない
      def success_response(data)
        response_data = {
          success: true
        }.merge(data)

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      end

      def error_response(message)
        ErrorResponseBuilder.new(message)
      end
    end

    class ErrorResponseBuilder
      def initialize(message)
        @data = { success: false, error: message }
      end

      def with(key, value = nil, **data)
        if key.is_a?(Hash)
          @data.merge!(key)
        elsif !data.empty?
          @data.merge!(data)
        else
          @data[key] = value
        end
        self
      end

      def add(key, value = nil, **data)
        with(key, value, **data)
      end

      def build
        MCP::Tool::Response.new([{
          type: "text",
          text: @data.to_json
        }])
      end
    end
  end
end
