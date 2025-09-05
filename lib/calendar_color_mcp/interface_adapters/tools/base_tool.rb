require 'mcp'
require_relative '../../loggable'
require_relative '../../logger_manager'

module InterfaceAdapters
  class BaseTool < MCP::Tool
    include CalendarColorMCP::Loggable
    
    class << self
      protected
      
      def logger
        @logger ||= CalendarColorMCP::LoggerManager.instance
      end


      def extract_token_manager(context)
        server_context = context[:server_context]
        token_manager = server_context&.dig(:token_manager)

        if token_manager.nil?
          raise ArgumentError, "Token manager is not available"
        end

        token_manager
      end

      def extract_oauth_service(context)
        server_context = context[:server_context]
        oauth_service = server_context&.dig(:oauth_service)

        oauth_service || raise(InterfaceAdapters::DependencyInjectionError, "oauth_service not found in server_context")
      end

      def extract_token_repository(context)
        server_context = context[:server_context]
        token_repository = server_context&.dig(:token_repository)

        token_repository || raise(InterfaceAdapters::DependencyInjectionError, "token_repository not found in server_context")
      end

      def extract_calendar_repository(context)
        server_context = context[:server_context]
        calendar_repository = server_context&.dig(:calendar_repository)

        calendar_repository || raise(InterfaceAdapters::DependencyInjectionError, "calendar_repository not found in server_context")
      end

      def success_response(data)
        response_data = {
          success: true
        }.merge(data)

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      end

      def error_response(message, **additional_data)
        response_data = {
          success: false,
          error: message
        }.merge(additional_data)

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      end
    end
  end
end