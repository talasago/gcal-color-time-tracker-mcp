require 'mcp'

module CalendarColorMCP
  class StartAuthTool < MCP::Tool
    description "Google Calendar認証を開始します"
    
    input_schema(
      type: "object",
      properties: {
        user_id: {
          type: "string",
          description: "ユーザーID"
        }
      },
      required: ["user_id"]
    )

    def self.call(user_id:, server_context: {})
      auth_manager = server_context[:auth_manager]
      auth_url = auth_manager.get_auth_url(user_id)

      response_data = {
        success: true,
        user_id: user_id,
        auth_url: auth_url,
        instructions: "上記URLにアクセスして認証を完了してください。認証後、再度分析を実行できます。"
      }

      MCP::Tool::Response.new([{
        type: "text",
        text: response_data.to_json
      }])
    end
  end
end