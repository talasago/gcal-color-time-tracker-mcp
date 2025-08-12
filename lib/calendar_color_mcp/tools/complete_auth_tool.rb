require 'mcp'
require_relative 'base_tool'

module CalendarColorMCP
  class CompleteAuthTool < BaseTool
    description "Google認証コードを使用して認証を完了します"

    input_schema(
      type: "object",
      properties: {
        auth_code: {
          type: "string",
          description: "Googleから取得した認証コード"
        }
      },
      required: ["auth_code"]
    )

    class << self
      def call(auth_code:, **context)
        logger.info "Completing authentication with provided code"
        logger.debug "Auth code provided: #{auth_code ? 'yes' : 'no'}"
        
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          logger.error "Failed to extract auth manager: #{e.message}"
          return error_response(e.message).build
        end

        if auth_code.nil? || auth_code.strip.empty?
          logger.error "No auth code provided"
          return error_response("認証コードが指定されていません").build
        end

        logger.debug "Processing authentication with code"
        result = auth_manager.complete_auth(auth_code.strip)
        
        if result[:success]
          logger.info "Authentication completed successfully"
        else
          logger.error "Authentication failed: #{result[:error]}"
        end

        MCP::Tool::Response.new([{
          type: "text",
          text: result.to_json
        }])
      end
    end
  end
end