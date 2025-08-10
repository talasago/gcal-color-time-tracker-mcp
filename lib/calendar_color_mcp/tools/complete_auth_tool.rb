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
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          return error_response(e.message).build
        end

        if auth_code.nil? || auth_code.strip.empty?
          return error_response("認証コードが指定されていません").build
        end

        result = auth_manager.complete_auth(auth_code.strip)

        MCP::Tool::Response.new([{
          type: "text",
          text: result.to_json
        }])
      end
    end
  end
end