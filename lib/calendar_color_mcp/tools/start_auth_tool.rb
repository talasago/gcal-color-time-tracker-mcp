require 'mcp'

module CalendarColorMCP
  class StartAuthTool < MCP::Tool
    description "Google Calendar認証を開始します"

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

        auth_url = auth_manager.get_auth_url
        instructions = auth_manager.get_auth_instructions

        response_data = {
          success: true,
          auth_url: auth_url,
          instructions: instructions
        }

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      end
    end
  end
end
