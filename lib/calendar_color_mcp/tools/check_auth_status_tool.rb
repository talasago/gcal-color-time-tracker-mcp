require 'mcp'

module CalendarColorMCP
  class CheckAuthStatusTool < MCP::Tool
    description "認証状態を確認します"
    
    input_schema(
      type: "object",
      properties: {},
      required: []
    )

    class << self
      def call(**context)
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

        authenticated = auth_manager.authenticated?

        result = {
          success: true,
          authenticated: authenticated
        }

        unless authenticated
          result[:auth_url] = auth_manager.get_auth_url
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
end