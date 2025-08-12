require 'mcp'
require_relative 'base_tool'

module CalendarColorMCP
  class StartAuthTool < BaseTool
    description "Google Calendar認証を開始します"

    input_schema(
      type: "object",
      properties: {},
      required: []
    )

    class << self
      def call(**context)
        logger.info "Starting authentication process"
        
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          logger.error "Failed to extract auth manager: #{e.message}"
          return error_response(e.message).build
        end

        auth_url = auth_manager.get_auth_url
        logger.info "Authentication URL generated successfully"
        logger.debug "Auth URL: #{auth_url}"

        success_response({
          auth_url: auth_url,
          instructions: auth_manager.get_auth_instructions
        })
      end
    end
  end
end
