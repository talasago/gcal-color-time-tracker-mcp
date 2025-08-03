require 'mcp'

module CalendarColorMCP
  class CheckAuthStatusTool < MCP::Tool
    description "認証状態を確認します"
    
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
      user_manager = server_context[:user_manager]
      auth_manager = server_context[:auth_manager]
      
      authenticated = user_manager.authenticated?(user_id)

      result = {
        success: true,
        user_id: user_id,
        authenticated: authenticated
      }

      unless authenticated
        result[:auth_url] = auth_manager.get_auth_url(user_id)
        result[:message] = "認証が必要です"
      else
        result[:message] = "認証済みです"
      end

      MCP::Tool::Response.new([{
        type: "text",
        text: result.to_json
      }])
    end
  end
end