require 'mcp'
require_relative 'base_tool'

module CalendarColorMCP
  class CheckAuthStatusTool < BaseTool
    description "認証状態を確認します"

    input_schema(
      type: "object",
      properties: {},
      required: []
    )

    class << self
      def call(**context)
        logger.info "Checking authentication status"
        
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          logger.error "Failed to extract auth manager: #{e.message}"
          return error_response(e.message).build
        end

        authenticated = auth_manager.token_exist?
        logger.debug "Authentication status: #{authenticated ? 'authenticated' : 'not authenticated'}"

        result = {
          authenticated: authenticated
        }

        if authenticated
          result[:message] = "認証済みです"
        else
          result[:auth_url] = auth_manager.get_auth_url
          result[:message] = "認証が必要です"
        end

        success_response(result)
      end
    end
  end
end
