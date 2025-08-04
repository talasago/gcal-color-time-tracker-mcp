require 'mcp'

module CalendarColorMCP
  class CompleteAuthTool < MCP::Tool
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
        server_context = context[:server_context]
        auth_manager = server_context&.dig(:auth_manager)

        unless auth_manager
          return MCP::Tool::Response.new([{
            type: "text",
            text: {
              success: false,
              error: "認証マネージャーが利用できません"
            }.to_json
          }])
        end

        if auth_code.nil? || auth_code.strip.empty?
          return MCP::Tool::Response.new([{
            type: "text",
            text: {
              success: false,
              error: "認証コードが指定されていません"
            }.to_json
          }])
        end

        # 認証コードを使用して認証を完了
        result = auth_manager.complete_auth(auth_code.strip)

        MCP::Tool::Response.new([{
          type: "text",
          text: result.to_json
        }])
      end
    end
  end
end