require 'mcp'
require_relative 'base_tool'

module InterfaceAdapters
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