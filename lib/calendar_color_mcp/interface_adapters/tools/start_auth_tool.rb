require 'mcp'
require_relative 'base_tool'

module InterfaceAdapters
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
          
          auth_url = auth_manager.get_auth_url
          logger.info "Authentication URL generated successfully"
          logger.debug "Auth URL: #{auth_url}"

          success_response({
            auth_url: auth_url,
            instructions: auth_manager.get_auth_instructions
          })
        rescue ArgumentError => e
          logger.error "Failed to extract auth manager: #{e.message}"
          error_response(e.message)
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("予期しないエラーが発生しました: #{e.message}")
        end
      end
    end
  end
end