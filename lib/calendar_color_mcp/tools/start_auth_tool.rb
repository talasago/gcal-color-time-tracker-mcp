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
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          return error_response(e.message).build
        end

        auth_url = auth_manager.get_auth_url
        instructions = auth_manager.get_auth_instructions

        success_response({
          auth_url: auth_url,
          instructions: instructions
        })
      end
    end
  end
end
